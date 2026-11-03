require "rails_helper"

RSpec.describe RecommendationBatch do
  subject { build(:recommendation_batch) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_many(:recommendations) }
  it { is_expected.to have_many(:llm_calls) }

  it do
    expect(subject).to define_enum_for(:status)
      .with_values(pending: "pending", processing: "processing", completed: "completed", failed: "failed")
      .with_prefix.backed_by_column_of_type(:string).validating
  end

  it do
    expect(subject).to define_enum_for(:ranked_by).with_values(agent: "agent", heuristic: "heuristic")
                                                  .with_prefix.backed_by_column_of_type(:string).validating(allowing_nil: true)
  end
end
