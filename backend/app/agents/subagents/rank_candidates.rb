module Subagents
  # complex tier (Opus) — the only Opus task (SPEC §4.4). Chooses and explains 10 books
  # from the pool; output is validated in Ruby before anything is trusted.
  class RankCandidates < ApplicationService
    MAX_CANDIDATES = 40
    SCHEMA = {
      type: "object", additionalProperties: false, required: %w[recommendations],
      properties: {
        recommendations: {
          type: "array",
          items: { type: "object", additionalProperties: false, required: %w[id score reason],
                   properties: { id: { type: "string" }, score: { type: "integer" }, reason: { type: "string" } } }
        }
      }
    }.freeze

    def initialize(llm:, profile:, pool:, persona: nil, feedback: nil)
      @llm = llm
      @profile = profile
      @pool = pool
      @persona = persona
      @feedback = feedback
    end

    # Returns [Validator::Ranked]; raises Recommendations::Validator::Invalid.
    def call
      input = { reader: @profile.to_prompt.merge(persona: @persona).compact,
                candidates: @pool.top(MAX_CANDIDATES).map(&:to_prompt) }
      input[:previous_attempt_errors] = @feedback if @feedback
      out = @llm.json(task: :rank_candidates, system: Llm::Prompt.for(:rank_candidates),
                      input:, schema: SCHEMA, max_tokens: 16_000)
      Recommendations::Validator.call(output: out, pool: @pool)
    end
  end
end
