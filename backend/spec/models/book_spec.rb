require "rails_helper"

RSpec.describe Book do
  subject { build(:book) }

  it { is_expected.to have_many(:user_books) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_uniqueness_of(:goodreads_book_id).allow_nil.case_insensitive }
  it { is_expected.to validate_uniqueness_of(:open_library_work_key).allow_nil }
  it { is_expected.to define_enum_for(:source).with_values(goodreads: "goodreads", open_library: "open_library").backed_by_column_of_type(:string).validating }

  it do
    expect(subject).to define_enum_for(:enrichment_status)
      .with_values(pending: "pending", enriched: "enriched", not_found: "not_found")
      .with_prefix(:enrichment).backed_by_column_of_type(:string).validating
  end

  it "defaults enrichment_status to pending" do
    expect(described_class.new.enrichment_status).to eq("pending")
  end
end
