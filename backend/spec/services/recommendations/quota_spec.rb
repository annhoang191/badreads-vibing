require "rails_helper"

RSpec.describe Recommendations::Quota do
  let(:user) { create(:user) }

  subject(:quota) { described_class.new(user:) }

  it "is full with no batches" do
    expect(quota.to_h).to eq(limit: 5, remaining: 5, resets_at: nil)
  end

  it "counts batches of any status and reports reset time when exhausted" do
    freeze_time do
      first = create(:recommendation_batch, user:, status: "failed", created_at: 3.hours.ago)
      4.times { create(:recommendation_batch, user:, status: "completed", created_at: 1.hour.ago) }

      expect(quota.remaining).to eq(0)
      expect(quota.resets_at).to eq(first.created_at + 24.hours)
      expect(quota.retry_after).to eq(21.hours.to_i)
    end
  end

  it "is not exhausted below the limit" do
    create_list(:recommendation_batch, 4, user:)
    expect(quota.to_h).to include(remaining: 1, resets_at: nil)
  end

  it "ignores batches older than 24h and other users' batches" do
    create(:recommendation_batch, user:, created_at: 25.hours.ago)
    create(:recommendation_batch)
    expect(quota.remaining).to eq(5)
  end

  it "frees a slot as the window rolls" do
    travel_to(Time.zone.parse("2026-01-01 12:00")) do
      5.times { create(:recommendation_batch, user:) }
      expect(quota.remaining).to eq(0)
    end
    travel_to(Time.zone.parse("2026-01-02 12:00:01")) do
      expect(described_class.new(user:).remaining).to eq(5)
    end
  end
end
