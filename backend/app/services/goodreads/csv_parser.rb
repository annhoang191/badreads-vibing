module Goodreads
  # Parses a Goodreads export into [rows, skipped]: CsvRow value objects plus
  # `{ row:, reason: }` hashes for rows that couldn't be used (FR-I6). `row` is the
  # 1-based record number with the header as row 1.
  class CsvParser < ApplicationService
    SHELVES = %w[read currently-reading to-read].freeze

    # io: an IO (StringIO, File) or a String
    def initialize(io:)
      @text = io.respond_to?(:read) ? io.read : io
    end

    def call
      rows = []
      skipped = []
      headers = nil

      CsvReader.records(@text).each.with_index(1) do |record, number|
        if headers.nil?
          headers = record.map(&:strip)
          next
        end

        rows << build(headers.zip(record).to_h)
      rescue ArgumentError, KeyError => e
        skipped << { row: number, reason: e.message }
      end

      [ rows, skipped ]
    end

    private

    def build(r)
      shelf = r["Exclusive Shelf"].to_s.strip
      raise ArgumentError, "Unknown shelf #{shelf.inspect}" unless SHELVES.include?(shelf)

      title = r["Title"].to_s.strip
      raise ArgumentError, "Missing Title" if title.empty?

      CsvRow.new(
        goodreads_book_id: book_id(r["Book Id"]),
        title:,
        author: text(r["Author"]),
        additional_authors: list(r["Additional Authors"]),
        isbn: isbn(r["ISBN"]),
        isbn13: isbn(r["ISBN13"]),
        avg_rating: decimal(r["Average Rating"]),
        num_pages: integer(r["Number of Pages"])&.then { |n| n.positive? ? n : nil },
        year_published: integer(r["Year Published"]),
        original_publication_year: integer(r["Original Publication Year"]),
        my_rating: integer(r["My Rating"])&.then { |n| (1..5).cover?(n) ? n : nil },
        exclusive_shelf: shelf,
        shelves: list(r["Bookshelves"]),
        date_read: date(r["Date Read"]),
        date_added: date(r["Date Added"]),
        read_count: integer(r["Read Count"]) || 0,
        review: text(r["My Review"])
      )
    end

    def book_id(value)
      id = unwrap(value)
      raise ArgumentError, "Missing Book Id" if id.empty?
      raise ArgumentError, "Invalid Book Id #{id.inspect}" unless id.match?(/\A\d+\z/)

      id
    end

    # Goodreads wraps ISBNs as ="0441172717" to stop spreadsheets mangling them.
    def unwrap(value) = value.to_s.strip.delete_prefix("=").delete('"').strip

    def isbn(value) = unwrap(value).presence

    def text(value) = value.to_s.strip.presence

    def list(value) = value.to_s.split(",").map(&:strip).compact_blank

    def integer(value)
      str = value.to_s.strip
      return if str.empty?

      Integer(str, 10)
    end

    def decimal(value)
      str = value.to_s.strip
      return if str.empty?

      BigDecimal(str).round(2)
    rescue ArgumentError
      raise ArgumentError, "Invalid Average Rating #{str.inspect}"
    end

    def date(value)
      str = value.to_s.strip
      return if str.empty?

      Date.strptime(str, "%Y/%m/%d")
    rescue Date::Error
      raise ArgumentError, "Invalid date #{str.inspect}"
    end
  end
end
