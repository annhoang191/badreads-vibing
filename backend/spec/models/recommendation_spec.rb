require "rails_helper"

RSpec.describe Recommendation do
  subject { build(:recommendation) }

  it { is_expected.to belong_to(:recommendation_batch) }
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:book) }
  it { is_expected.to validate_inclusion_of(:position).in_range(1..10) }
  it { is_expected.to validate_uniqueness_of(:book_id).scoped_to(:recommendation_batch_id) }

  it do
    expect(subject).to define_enum_for(:status).with_values(new: "new", saved: "saved", dismissed: "dismissed")
                                               .with_prefix.backed_by_column_of_type(:string).validating
  end

  it "exposes status_new?" do
    expect(build(:recommendation, status: "new")).to be_status_new
  end
end
