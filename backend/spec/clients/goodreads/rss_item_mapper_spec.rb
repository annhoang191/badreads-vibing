require "rails_helper"

RSpec.describe Goodreads::RssItemMapper do
  def item(**overrides)
    Goodreads::RssItem.new(**{
      book_id: "1", title: "Dune", author_name: "Frank Herbert", isbn: "0441172717", user_rating: "4",
      user_read_at: "Tue, 14 Mar 2023 00:00:00 -0700", user_date_added: "Sun, 01 Jan 2023 10:22:31 +0900",
      user_shelves: "sci-fi, favorites", image_url: "https://i.gr-assets.com/dune_large.jpg",
      average_rating: "4.27", book_published: "1965", num_pages: "604"
    }.merge(overrides))
  end

  it "maps fields" do
    row = described_class.call(item, shelf: "read")

    expect(row).to have_attributes(
      goodreads_book_id: "1", title: "Dune", author: "Frank Herbert", isbn: "0441172717", isbn13: nil,
      my_rating: 4, exclusive_shelf: "read", avg_rating: BigDecimal("4.27"), num_pages: 604,
      original_publication_year: 1965, year_published: nil, read_count: nil,
      cover_url: "https://i.gr-assets.com/dune_large.jpg"
    )
  end

  it "keeps the local calendar date" do
    row = described_class.call(item, shelf: "read")
    expect(row.date_read).to eq(Date.new(2023, 3, 14))
    expect(row.date_added).to eq(Date.new(2023, 1, 1))
  end

  it "maps rating 0 to nil" do
    expect(described_class.call(item(user_rating: "0"), shelf: "read").my_rating).to be_nil
  end

  it "combines user shelves with the requested shelf without duplicates" do
    expect(described_class.call(item, shelf: "read").shelves).to eq(%w[sci-fi favorites read])
    expect(described_class.call(item(user_shelves: "to-read"), shelf: "to-read").shelves).to eq(%w[to-read])
    expect(described_class.call(item(user_shelves: nil), shelf: "to-read").shelves).to eq(%w[to-read])
  end

  it "drops placeholder covers and unparsable values" do
    row = described_class.call(item(image_url: "https://s.gr-assets.com/assets/nophoto/book/111x148.png",
                                    user_read_at: "garbage", num_pages: "0", average_rating: nil), shelf: "read")
    expect(row).to have_attributes(cover_url: nil, date_read: nil, num_pages: nil, avg_rating: nil)
  end

  it "builds a row the Upserter accepts" do
    expect(described_class.call(item, shelf: "read").book_attributes).to include(:cover_url, :title)
  end
end
