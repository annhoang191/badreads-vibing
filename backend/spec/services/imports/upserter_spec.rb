require "rails_helper"

RSpec.describe Imports::Upserter do
  let(:user) { create(:user) }

  def row(id, **overrides)
    Goodreads::CsvRow.new(
      goodreads_book_id: id.to_s, title: "Book #{id}", author: "Author #{id}", additional_authors: [],
      isbn: nil, isbn13: "978#{id}", avg_rating: BigDecimal("4.1"), num_pages: 300, year_published: 2000,
      original_publication_year: 1999, my_rating: 4, exclusive_shelf: "read", shelves: %w[read fav],
      date_read: Date.new(2024, 1, 1), date_added: Date.new(2023, 1, 1), read_count: 1, review: nil
    ).with(**overrides)
  end

  it "creates books and shelvings with stats" do
    stats = described_class.call(user:, rows: [ row(1), row(2) ])

    expect(stats).to include(rows_total: 2, books_created: 2, books_updated: 0, shelvings_created: 2,
                             shelvings_updated: 0, missing_from_source: 0)
    expect(user.user_books.count).to eq(2)
    expect(Book.find_by(goodreads_book_id: "1")).to have_attributes(source: "goodreads", num_pages: 300)
  end

  it "is idempotent: a second run creates nothing and changes no rows" do
    rows = [ row(1), row(2) ]
    described_class.call(user:, rows:)

    expect { @stats = described_class.call(user:, rows:) }.not_to change { [ Book.count, UserBook.count ] }
    expect(@stats).to include(books_created: 0, books_updated: 2, shelvings_created: 0, shelvings_updated: 2)
  end

  it "keeps enriched num_pages and original_publication_year when a CSV re-import has nil for them" do
    described_class.call(user:, rows: [ row(1, num_pages: nil, original_publication_year: nil) ])
    Book.find_by(goodreads_book_id: "1").update!(num_pages: 412, original_publication_year: 1965)

    described_class.call(user:, rows: [ row(1, num_pages: nil, original_publication_year: nil, title: "Retitled") ])

    expect(Book.find_by(goodreads_book_id: "1")).to have_attributes(num_pages: 412, original_publication_year: 1965,
                                                                    title: "Retitled")
  end

  it "still overwrites num_pages when the CSV carries a value" do
    described_class.call(user:, rows: [ row(1, num_pages: 300) ])
    described_class.call(user:, rows: [ row(1, num_pages: 350) ])

    expect(Book.find_by(goodreads_book_id: "1").num_pages).to eq(350)
  end

  it "counts changed values as updates and applies them" do
    described_class.call(user:, rows: [ row(1) ])
    stats = described_class.call(user:, rows: [ row(1, my_rating: 2, title: "New title"), row(3) ])

    expect(stats).to include(books_created: 1, books_updated: 1, shelvings_created: 1, shelvings_updated: 1)
    expect(user.user_books.joins(:book).find_by(books: { goodreads_book_id: "1" }).my_rating).to eq(2)
    expect(Book.find_by(goodreads_book_id: "1").title).to eq("New title")
  end

  it "lets a CSV overwrite with blanks (except the enrichable book columns)" do
    described_class.call(user:, rows: [ row(1) ])
    described_class.call(user:, rows: [ row(1, my_rating: nil, num_pages: nil, year_published: nil) ])

    expect(Book.find_by(goodreads_book_id: "1")).to have_attributes(num_pages: 300, year_published: nil)
    expect(user.user_books.first.my_rating).to be_nil
  end

  it "does not null existing values when the source is rss" do
    described_class.call(user:, rows: [ row(1) ])
    stats = described_class.call(user:, source: :rss,
                                 rows: [ row(1, my_rating: nil, num_pages: nil, date_read: nil, shelves: [], title: "RSS title") ])

    book = Book.find_by(goodreads_book_id: "1")
    user_book = user.user_books.first
    expect(book).to have_attributes(title: "RSS title", num_pages: 300, isbn13: "9781")
    expect(user_book).to have_attributes(my_rating: 4, date_read: Date.new(2024, 1, 1), shelves: %w[read fav])
    expect(stats).to include(books_created: 0, shelvings_updated: 1, missing_from_source: 0)
  end

  it "inserts new rss rows that lack some values" do
    described_class.call(user:, source: :rss, rows: [ row(1, my_rating: nil, shelves: [], num_pages: nil) ])

    expect(user.user_books.first).to have_attributes(my_rating: nil, shelves: [])
  end

  it "counts goodreads shelvings absent from the CSV without deleting them" do
    described_class.call(user:, rows: [ row(1), row(2), row(3) ])
    stats = described_class.call(user:, rows: [ row(1) ])

    expect(stats[:missing_from_source]).to eq(2)
    expect(user.user_books.count).to eq(3)
  end

  it "only looks at the given user's shelvings and collapses duplicate Book Ids" do
    other = create(:user_book)
    stats = described_class.call(user:, rows: [ row(1), row(1, my_rating: 1) ])

    expect(stats).to include(rows_total: 1, missing_from_source: 0)
    expect(user.user_books.first.my_rating).to eq(1)
    expect(other.reload.user).not_to eq(user)
  end
end
