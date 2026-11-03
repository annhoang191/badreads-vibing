require "rails_helper"

RSpec.describe RecommendationOrchestrator do
  let(:profile) { rec_profile }
  let(:pool) { pool_with(15, profile:) }
  let(:source) { instance_double(Recommendations::CandidateSource, fetch: raw_candidates(25).last(10)) }
  let(:limits) { Llm::Router.agent_limits }
  let(:persona) { { "persona" => "You love thoughtful space opera.", "likes" => [], "dislikes" => [] } }

  def run(llm, **opts) = described_class.call(llm:, profile:, pool:, source:, limits:, **opts)

  it "runs search -> summarize -> rank -> submit and returns the validated ranking" do
    llm = FakeLlm::Client.new(
      turns: [
        FakeLlm.tool_use([ "search_candidates", { "subjects" => [ "space opera" ], "authors" => [], "queries" => [] } ],
                         [ "summarize_reader", {} ]),
        FakeLlm.tool_use([ "rank_candidates", {} ]),
        FakeLlm.tool_use([ "submit_recommendations", {} ])
      ],
      json: { summarize_reader: persona, rank_candidates: ->(input, _) { ranking_for(pool).tap { expect(input[:reader][:persona]).to eq(persona["persona"]) } } }
    )

    result = run(llm)

    expect(result.ranked.size).to eq(10)
    expect(result.turns).to eq(3)
    expect(pool.size).to eq(25)
    expect(source).to have_received(:fetch).with(subjects: [ "space opera" ], authors: [], queries: [])
    # parallel tool calls answered in ONE user message, one result per tool_use
    tool_results = llm.created[1][:messages][2][:content]
    expect(tool_results.map { |r| r[:tool_use_id] }).to eq(%w[tu_search_candidates_0 tu_summarize_reader_1])
  end

  it "feeds validation errors back and lets the ranker retry once" do
    bad = ranking_for(pool).tap { |o| o["recommendations"][0]["id"] = "c999" }
    llm = FakeLlm::Client.new(
      turns: [ FakeLlm.tool_use([ "rank_candidates", {} ]), FakeLlm.tool_use([ "rank_candidates", {} ]),
               FakeLlm.tool_use([ "submit_recommendations", {} ]) ],
      json: { rank_candidates: ->(input, n) { n == 1 ? bad : ranking_for(pool).tap { expect(input[:previous_attempt_errors]).to include(/unknown id/) } } }
    )

    expect(run(llm).ranked.size).to eq(10)
    first_result = llm.created.last[:messages][2][:content].first
    expect(first_result).to include(is_error: true)
    expect(first_result[:content]).to include("failed validation")
  end

  it "enforces per-tool call caps" do
    llm = FakeLlm::Client.new(
      turns: [ FakeLlm.tool_use(*Array.new(3) { [ "rank_candidates", {} ] }), FakeLlm.tool_use([ "submit_recommendations", {} ]) ],
      json: { rank_candidates: ranking_for(pool) }
    )
    run(llm)
    results = llm.created[1][:messages][2][:content]
    expect(results.map { |r| r[:is_error] }).to eq([ false, false, true ])
    expect(llm.json_calls[:rank_candidates].size).to eq(2)
  end

  it "refuses to submit before a valid ranking exists" do
    llm = FakeLlm::Client.new(
      turns: [ FakeLlm.tool_use([ "submit_recommendations", {} ]), FakeLlm.tool_use([ "rank_candidates", {} ]),
               FakeLlm.tool_use([ "submit_recommendations", {} ]) ],
      json: { rank_candidates: ranking_for(pool) }
    )
    expect(run(llm).turns).to eq(3)
    expect(llm.created.last[:messages][2][:content].first[:content]).to include("no valid ranking")
  end

  it "fails after max turns" do
    turns = Array.new(limits["max_turns"] + 1) { FakeLlm.tool_use([ "get_reading_profile", {} ]) }
    expect { run(FakeLlm::Client.new(turns:)) }.to raise_error(described_class::Failed, /max turns/)
  end

  it "fails when the token budget is exceeded" do
    big = FakeLlm.tool_use([ "get_reading_profile", {} ]).tap { |r| r.usage = FakeLlm.usage(70_000, 10) }
    expect { run(FakeLlm::Client.new(turns: [ big, big ])) }.to raise_error(described_class::Failed, /token budget/)
  end

  it "fails when the wall clock runs out" do
    times = [ 0, 0, 1_000 ].each
    llm = FakeLlm::Client.new(turns: [ FakeLlm.tool_use([ "get_reading_profile", {} ]) ] * 3)
    expect { run(llm, clock: -> { times.next }) }.to raise_error(described_class::Failed, /wall clock/)
  end

  it "nudges a model that stops talking, then gives up" do
    llm = FakeLlm::Client.new(turns: [ FakeLlm.text("done", model: "claude-sonnet-5-5") ] * 3)
    expect { run(llm) }.to raise_error(described_class::Failed, /without submitting/)
    expect(llm.created.last[:messages][2][:content]).to eq(described_class::NUDGE)
  end

  it "turns model failures into Failed" do
    llm = FakeLlm::Client.new
    allow(llm).to receive(:create).and_raise(Llm::Client::Refused, "declined")
    expect { run(llm) }.to raise_error(described_class::Failed, /declined/)
  end

  it "defines strict tool schemas" do
    expect(described_class::TOOLS).to all(include(strict: true))
    expect(described_class::TOOLS.map { |t| t[:input_schema][:additionalProperties] }).to all(be(false))
  end
end
