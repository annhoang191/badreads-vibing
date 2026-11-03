require "rails_helper"

RSpec.describe ComputeInsightsJob do
  let(:user) { create(:user) }

  it "stores the snapshot in reading_insights" do
    create(:user_book, user:, my_rating: 5)

    described_class.perform_now(user.id)

    insight = user.reload.reading_insight
    expect(insight.version).to eq(1)
    expect(insight.computed_at).to be_present
    expect(insight.data["metrics"]["totals"]["read"]).to eq(1)
  end

  it "updates the existing row" do
    described_class.perform_now(user.id)
    create(:user_book, user:)

    expect { described_class.perform_now(user.id) }.not_to change(ReadingInsight, :count)
    expect(user.reload.reading_insight.data["metrics"]["totals"]["read"]).to eq(1)
  end

  it "discards for a missing user" do
    expect { described_class.perform_now(0) }.not_to raise_error
  end
end
