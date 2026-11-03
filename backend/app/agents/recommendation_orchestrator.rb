# Orchestrator agent (orchestrator tier, Sonnet) — SPEC §4.4.
#
# Plans the run and delegates: deterministic tools (profile, candidate search) and
# model-tiered subagents (Haiku: expand_queries, summarize_reader; Opus: rank_candidates).
# The agent loop is written by hand (not the SDK tool runner) so every guardrail is
# enforced between turns: max turns, token budget, wall clock, and per-tool call caps.
# Any guardrail breach or model failure raises Failed; the pipeline then falls back to
# the heuristic ranking (FR-C7).
class RecommendationOrchestrator
  class Failed < StandardError; end

  Result = Data.define(:ranked, :turns, :tokens)

  NUDGE = "Finish the run: call rank_candidates if you haven't, then submit_recommendations.".freeze
  MAX_NUDGES = 2

  def self.call(...) = new(...).call

  def initialize(llm:, profile:, pool:, source:, limits: Llm::Router.agent_limits,
                 clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
    @llm = llm
    @profile = profile
    @pool = pool
    @source = source
    @limits = limits
    @clock = clock
    @calls = Hash.new(0)
    @persona = nil
    @ranked = nil
    @submitted = false
    @turns = 0
    @tokens = 0
    @nudges = 0
  end

  def call
    deadline = @clock.call + @limits.fetch("wall_clock_seconds")
    messages = [ { role: "user", content: opening_message } ]

    until @submitted
      enforce_limits!(deadline)
      response = @llm.create(task: :orchestrate_recommendations, system: Llm::Prompt.for(:orchestrate_recommendations),
                             messages:, tools: TOOLS, max_tokens: 4_000)
      @turns += 1
      @tokens += response.usage.input_tokens.to_i + response.usage.output_tokens.to_i
      messages << { role: "assistant", content: response.content.map(&:to_h) }

      tool_uses = response.content.select { |b| b.type == :tool_use }
      if tool_uses.any?
        messages << { role: "user", content: tool_uses.map { |b| run_tool(b) } }
      else
        nudge!(messages)
      end
    end

    Result.new(ranked: @ranked, turns: @turns, tokens: @tokens)
  rescue Llm::Client::Error => e
    raise Failed, "orchestrator model call failed: #{e.message}"
  end

  private

  def enforce_limits!(deadline)
    raise Failed, "max turns (#{@limits['max_turns']}) reached" if @turns >= @limits.fetch("max_turns")
    raise Failed, "token budget (#{@limits['token_budget']}) exceeded" if @tokens > @limits.fetch("token_budget")
    raise Failed, "wall clock (#{@limits['wall_clock_seconds']}s) exceeded" if @clock.call > deadline
  end

  def nudge!(messages)
    raise Failed, "agent stopped without submitting" if (@nudges += 1) > MAX_NUDGES

    messages << { role: "user", content: NUDGE }
  end

  def opening_message
    preview = @pool.top(15).map { |c| "#{c.id}: #{c.title} — #{c.author} (#{c.subjects.first(3).join(', ')})" }
    JSON.pretty_generate(
      reader_profile: @profile.to_prompt,
      initial_pool: { size: @pool.size, top_by_prescore: preview }
    )
  end

  # Every tool_use gets exactly one tool_result, in one user message (parallel-safe).
  def run_tool(block)
    name = block.name.to_s
    input = (block.input || {}).to_h.deep_stringify_keys
    cap = @limits.fetch("max_tool_calls").fetch(name, nil)
    if cap && @calls[name] >= cap
      return result(block, { error: "#{name} may be called at most #{cap} times" }, error: true)
    end

    @calls[name] += 1
    result(block, dispatch(name, input))
  rescue Recommendations::Validator::Invalid => e
    result(block, { error: "ranking failed validation", details: e.errors }, error: true)
  rescue Llm::Client::Error, OpenLibrary::Client::Error, ArgumentError => e
    result(block, { error: e.message.truncate(300) }, error: true)
  end

  def dispatch(name, input)
    case name
    when "get_reading_profile" then @profile.to_prompt
    when "search_candidates" then search(input)
    when "expand_queries" then { queries: Subagents::ExpandQueries.call(llm: @llm, profile: @profile) }
    when "summarize_reader"
      @persona = Subagents::SummarizeReader.call(llm: @llm, profile: @profile)
      @persona
    when "rank_candidates" then rank
    when "submit_recommendations" then submit
    else raise ArgumentError, "unknown tool #{name}"
    end
  end

  def search(input)
    raws = @source.fetch(subjects: clean(input["subjects"]), authors: clean(input["authors"]),
                         queries: clean(input["queries"]))
    added = @pool.add(raws)
    { added: added.size, pool_size: @pool.size,
      new_top: added.sort_by { |c| -c.pre_score }.first(10).map { |c| "#{c.id}: #{c.title} — #{c.author}" } }
  end

  def clean(list) = Array(list).map { |s| s.to_s.strip }.reject(&:blank?).first(8)

  def rank
    raise ArgumentError, "the pool has fewer than #{Recommendations::Validator::COUNT} candidates; search first" if @pool.size < Recommendations::Validator::COUNT

    feedback = @last_rank_errors
    @ranked = Subagents::RankCandidates.call(llm: @llm, profile: @profile, pool: @pool,
                                             persona: @persona&.fetch("persona", nil), feedback:)
    { ok: true, ready: @ranked.size, next: "call submit_recommendations" }
  rescue Recommendations::Validator::Invalid => e
    @last_rank_errors = e.errors
    raise
  end

  def submit
    raise ArgumentError, "no valid ranking yet; call rank_candidates first" unless @ranked

    @submitted = true
    { ok: true }
  end

  def result(block, payload, error: false)
    { type: "tool_result", tool_use_id: block.id, content: JSON.generate(payload), is_error: error }
  end

  def self.tool(name, description, properties = {})
    { name:, description:, strict: true,
      input_schema: { type: "object", additionalProperties: false, properties:, required: properties.keys.map(&:to_s) } }
  end

  STRING_LIST = { type: "array", items: { type: "string" } }.freeze

  TOOLS = [
    tool("get_reading_profile", "Return the reader's profile (subjects, authors, loved and disliked books)."),
    tool("search_candidates",
         "Add Open Library books to the candidate pool. Give subjects, authors and/or free-form themes " \
         "(use empty arrays for unused fields). Books the reader has shelved are excluded automatically.",
         { subjects: STRING_LIST, authors: STRING_LIST, queries: STRING_LIST }),
    tool("expand_queries", "Suggest up to 5 fresh subject-style themes based on the reader's taste."),
    tool("summarize_reader", "Write a short reading persona that the ranker will use."),
    tool("rank_candidates", "Have the ranker choose and explain the final 10 books from the current pool."),
    tool("submit_recommendations", "Finish the run with the most recent valid ranking.")
  ].freeze
end
