require "rails_helper"

RSpec.describe Goodreads::SyncProfile do
  let(:user) { create(:user) }
  let(:profile) { create(:goodreads_profile, user:, goodreads_user_id: "1001", rss_enabled: true) }
  let(:page1) { file_fixture("goodreads_rss_read_page1.xml").read }
  let(:empty) { file_fixture("goodreads_rss_read_page2.xml").read }
  let(:feed) { "https://www.goodreads.com/review/list_rss/1001" }

  def stub_shelf(shelf, body, status: 200)
    stub_request(:get, feed).with(query: hash_including(shelf:, page: "1")).to_return(status:, body:)
    stub_request(:get, feed).with(query: hash_including(shelf:, page: "2")).to_return(status: 200, body: empty)
  end

  def stub_all(read: page1)
    stub_shelf("read", read)
    stub_shelf("currently-reading", empty)
    stub_shelf("to-read", empty)
  end

  it "imports books, records stats and resets failures" do
    stub_all
    profile.update!(consecutive_failures: 2, last_error: "boom")

    import = described_class.call(profile:)

    expect(import).to have_attributes(source: "rss", status: "completed")
    expect(import.stats).to include("rows_total" => 2, "books_created" => 2, "shelvings_created" => 2)
    expect(profile.reload).to have_attributes(consecutive_failures: 0, last_error: nil)
    expect(profile.last_synced_at).to be_present
    ub = user.user_books.joins(:book).find_by(books: { goodreads_book_id: "234225" })
    expect(ub).to have_attributes(my_rating: 5, exclusive_shelf: "read", date_read: Date.new(2023, 3, 14))
    expect(Book.find_by(goodreads_book_id: "234225").cover_url).to include("dune_large")
  end

  it "does not overwrite richer CSV data with blanks" do
    book = create(:book, goodreads_book_id: "999001", title: "Obscure Pamphlet", num_pages: 80, isbn: "123")
    create(:user_book, user:, book:, exclusive_shelf: "read", my_rating: 3, date_read: Date.new(2020, 1, 1))
    stub_all

    described_class.call(profile:)

    expect(book.reload).to have_attributes(num_pages: 80, isbn: "123")
    expect(user.user_books.find_by(book:)).to have_attributes(my_rating: 3, date_read: Date.new(2020, 1, 1))
  end

  it "is idempotent" do
    stub_all
    described_class.call(profile:)
    second = described_class.call(profile:)
    expect(second.stats).to include("books_created" => 0, "shelvings_created" => 0)
    expect(Book.count).to eq(2)
  end

  it "uses a provided pending import" do
    stub_all
    pending = described_class.start_import!(profile)
    expect(described_class.call(profile:, import: pending)).to eq(pending)
    expect(pending.reload.status).to eq("completed")
  end

  describe "failure" do
    before { stub_shelf("read", "", status: 404) }

    it "marks the import failed and counts the failure" do
      import = described_class.call(profile:)

      expect(import).to have_attributes(status: "failed", error_message: be_present)
      expect(profile.reload).to have_attributes(consecutive_failures: 1, last_error: be_present, rss_enabled: true)
    end

    it "disables rss after 3 consecutive failures" do
      3.times { described_class.call(profile:) }
      expect(profile.reload).to have_attributes(consecutive_failures: 3, rss_enabled: false)
    end
  end

  it "raises Conflict when another import is active" do
    create(:import, user:, status: "processing")
    expect { described_class.call(profile:) }.to raise_error(ApiError::Conflict)
  end
end
