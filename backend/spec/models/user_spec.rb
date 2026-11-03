require "rails_helper"

RSpec.describe User do
  subject { build(:user) }

  it { is_expected.to have_secure_password }
  it { is_expected.to have_many(:sessions).dependent(:delete_all) }
  it { is_expected.to have_one(:goodreads_profile).dependent(:delete) }
  it { is_expected.to have_many(:user_books).dependent(:delete_all) }
  it { is_expected.to have_many(:imports).dependent(:delete_all) }
  it { is_expected.to have_one(:reading_insight).dependent(:delete) }
  it { is_expected.to have_many(:recommendation_batches).dependent(:delete_all) }
  it { is_expected.to have_many(:recommendations).dependent(:delete_all) }
  it { is_expected.to validate_presence_of(:email_address) }
  it { is_expected.to validate_uniqueness_of(:email_address).case_insensitive }
  it { is_expected.to validate_length_of(:password).is_at_least(10) }

  it "normalizes email" do
    expect(build(:user, email_address: "  Foo@Example.COM ").email_address).to eq("foo@example.com")
  end

  it "rejects malformed email" do
    expect(build(:user, email_address: "nope")).not_to be_valid
  end

  it "cascades to owned rows at the database level" do
    user = create(:user)
    create(:session, user:)
    create(:user_book, user:)
    create(:import, user:)

    expect { user.delete }.to change(Session, :count).by(-1).and change(UserBook, :count).by(-1)
                                                         .and change(Import, :count).by(-1)
  end
end
