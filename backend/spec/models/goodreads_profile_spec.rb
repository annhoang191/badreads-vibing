require "rails_helper"

RSpec.describe GoodreadsProfile do
  subject { build(:goodreads_profile) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:goodreads_user_id) }
  it { is_expected.to validate_uniqueness_of(:user_id) }
end
