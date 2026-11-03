require "rails_helper"

RSpec.describe GenerateRecommendationsJob do
  it "runs the pipeline for a pending batch" do
    batch = create(:recommendation_batch)
    expect(Recommendations::Pipeline).to receive(:call).with(batch:)
    described_class.perform_now(batch.id)
  end

  it "does nothing for a batch that already started (retry-safe)" do
    batch = create(:recommendation_batch, status: "completed")
    expect(Recommendations::Pipeline).not_to receive(:call)
    described_class.perform_now(batch.id)
  end
end
