require "rails_helper"

RSpec.describe Llm::Router do
  it "resolves each task to its tier" do
    expect(described_class.for(:rank_candidates)).to have_attributes(name: "complex", model: "claude-opus-5-5", effort: "high")
    expect(described_class.for(:orchestrate_recommendations)).to have_attributes(name: "orchestrator", model: "claude-sonnet-5-5")
    expect(described_class.for(:summarize_reader)).to have_attributes(name: "simple", model: "claude-haiku-5-5", fallbacks: false)
  end

  it "allows only rank_candidates on the complex (Opus) tier" do
    expect(described_class.tasks_on(:complex)).to eq([ "rank_candidates" ])
  end

  it "rejects unknown tasks" do
    expect { described_class.for(:write_poem) }.to raise_error(Llm::Router::UnknownTask)
  end
end
