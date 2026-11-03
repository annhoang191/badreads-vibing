require "rails_helper"

RSpec.describe Recommendations::Pipeline do
  let(:user) { create(:user) }
  let(:batch) { create(:recommendation_batch, user:) }
  let(:source) { instance_double(Recommendations::CandidateSource, fetch: raw_candidates(20, authors: %w[A B C D E F])) }

  before do
    12.times { |i| create(:user_book, user:, my_rating: i.even? ? 5 : 4, book: create(:book, author: "Author #{i % 3}")) }
  end

  def orchestrator_returning(&block)
    Class.new do
      define_singleton_method(:call) { |**kw| block.call(**kw) }
    end
  end

  it "persists the agent's ranking" do
    orchestrator = orchestrator_returning do |pool:, **|
      ranked = Recommendations::Validator.call(output: ranking_for(pool), pool:)
      RecommendationOrchestrator::Result.new(ranked:, turns: 4, tokens: 9_000)
    end
    create(:llm_call, recommendation_batch: batch, tier: "complex", cost_usd: 0.05) if FactoryBot.factories.registered?(:llm_call)

    described_class.call(batch:, source:, llm: FakeLlm::Client.new, orchestrator:)

    batch.reload
    expect(batch).to have_attributes(status: "completed", ranked_by: "agent", agent_turns: 4, prompt_version: Llm::Router.prompt_version)
    recs = batch.recommendations.order(:position)
    expect(recs.map(&:position)).to eq((1..10).to_a)
    expect(recs.first.book).to have_attributes(source: "open_library", open_library_work_key: start_with("/works/"))
    expect(recs.first.reason).to include("Ancillary Justice")
  end

  it "falls back to the heuristic ranking when the agent fails (FR-C7)" do
    orchestrator = orchestrator_returning { |**| raise RecommendationOrchestrator::Failed, "max turns" }

    described_class.call(batch:, source:, llm: FakeLlm::Client.new, orchestrator:)

    expect(batch.reload).to have_attributes(status: "completed", ranked_by: "heuristic")
    expect(batch.recommendations.count).to eq(10)
  end

  it "reuses existing books by work key instead of duplicating them" do
    existing = create(:book, source: "open_library", goodreads_book_id: nil, open_library_work_key: "/works/OL20W", title: "Book 20")
    orchestrator = orchestrator_returning { |**| raise RecommendationOrchestrator::Failed, "x" }
    described_class.call(batch:, source:, llm: FakeLlm::Client.new, orchestrator:)
    expect(Book.where(open_library_work_key: "/works/OL20W").count).to eq(1)
    expect(batch.recommendations.pluck(:book_id)).to include(existing.id)
  end

  it "fails the batch with a friendly message when there aren't enough candidates" do
    allow(source).to receive(:fetch).and_return(raw_candidates(3))
    described_class.call(batch:, source:, llm: FakeLlm::Client.new, orchestrator: RecommendationOrchestrator)
    expect(batch.reload).to have_attributes(status: "failed", error_message: /couldn't find enough/)
  end

  it "never recommends a book the user already shelved" do
    shelved = create(:book, title: "Book 1", author: "A")
    create(:user_book, user:, book: shelved, exclusive_shelf: "to-read", my_rating: nil, date_read: nil)
    orchestrator = orchestrator_returning { |**| raise RecommendationOrchestrator::Failed, "x" }
    described_class.call(batch:, source:, llm: FakeLlm::Client.new, orchestrator:)
    expect(batch.recommendations.joins(:book).pluck("books.title")).not_to include("Book 1")
  end
end
