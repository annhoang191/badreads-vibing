module Goodreads
  # Converts an RssItem into the row object Imports::Upserter expects. nil means "RSS doesn't know",
  # which the Upserter (source: :rss) never writes (FR-R4).
  class RssItemMapper
    def self.call(item, shelf:) = new(item, shelf).call

    def initialize(item, shelf)
      @item = item
      @shelf = shelf
    end

    def call
      RssRow.new(
        goodreads_book_id: @item.book_id, title: @item.title, author: @item.author_name,
        additional_authors: [], isbn: isbn, isbn13: nil,
        avg_rating: decimal(@item.average_rating), num_pages: positive_int(@item.num_pages),
        year_published: nil, original_publication_year: positive_int(@item.book_published),
        my_rating: rating, exclusive_shelf: @shelf, shelves: shelves,
        date_read: date(@item.user_read_at), date_added: date(@item.user_date_added),
        read_count: nil, review: nil, cover_url: cover_url
      )
    end

    private

    def isbn = @item.isbn.to_s.delete('="').presence

    def shelves = (@item.user_shelves.to_s.split(",").map(&:strip).compact_blank + [ @shelf ]).uniq

    def rating
      n = @item.user_rating.to_i
      (1..5).cover?(n) ? n : nil
    end

    def positive_int(value)
      n = Integer(value.to_s, 10, exception: false)
      n&.positive? ? n : nil
    end

    def decimal(value)
      BigDecimal(value.to_s).round(2) if value.present?
    rescue ArgumentError
      nil
    end

    def date(value)
      DateTime.parse(value.to_s).to_date if value.present?
    rescue ArgumentError
      nil
    end

    def cover_url
      url = @item.image_url
      url.presence unless url.nil? || url.include?("nophoto")
    end
  end
end
