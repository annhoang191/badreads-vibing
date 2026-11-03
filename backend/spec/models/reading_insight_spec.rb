require "rails_helper"

RSpec.describe ReadingInsight do
  subject { build(:reading_insight) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_uniqueness_of(:user_id) }
end
