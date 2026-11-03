require "rails_helper"

RSpec.describe UserBook do
  subject { build(:user_book) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:book) }
  it { is_expected.to validate_uniqueness_of(:book_id).scoped_to(:user_id) }
  it { is_expected.to validate_inclusion_of(:my_rating).in_range(1..5).allow_nil }

  it do
    expect(subject).to define_enum_for(:exclusive_shelf)
      .with_values(read: "read", currently_reading: "currently-reading", to_read: "to-read")
      .with_prefix(:shelf).backed_by_column_of_type(:string).validating
  end

  it "maps currently_reading to the Goodreads value" do
    expect(described_class.exclusive_shelves[:currently_reading]).to eq("currently-reading")
  end

  it "enforces the rating range in the database" do
    user_book = create(:user_book)
    expect { user_book.update_column(:my_rating, 6) }.to raise_error(ActiveRecord::StatementInvalid)
  end
end
