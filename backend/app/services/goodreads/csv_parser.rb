module Goodreads
  # Parses a Goodreads export into [rows, skipped]: CsvRow value objects plus
  # `{ row:, reason: }` hashes for rows that couldn't be used (FR-I6). `row` is the
  # 1-based record number with the header as row 1.
  class CsvParser < ApplicationService
    SHELVES = %w[read currently-reading to-read].freeze

    # io: an IO (StringIO, File) or a String.
    # Returns [rows, skipped, warnings]. Header matching ignores case and stray whitespace.
    def initialize(io:)
      @text = io.respond_to?(:read) ? io.read : io
    end

    def call
      rows = []
      skipped = []
      headers = nil

      CsvReader.records(@text).each.with_index(1) do |record, number|
        if headers.nil?
          headers = record.map { |h| CsvText.header_key(h) }
          next
        end

        rows << build(headers.zip(record).to_h)
      rescue ArgumentError, KeyError => e
        skipped << { row: number, reason: e.message }
      end

      [ rows, skipped, warnings(headers || []) ]
    end

    # Columns we can import without, but whose absence the user should know about.
    OPTIONAL_COLUMNS = { "my rating" => "My Rating", "date read" => "Date Read", "bookshelves" => "Bookshelves" }.freeze

    def warnings(headers)
      OPTIONAL_COLUMNS.reject { |key, _| headers.include?(key) }
                      .map { |_, name| "Column \"#{name}\" was not found, so it wasn't imported." }
    end

    private

    def build(r)
      shelf = CsvText.clean(r["exclusive shelf"]).downcase
      raise ArgumentError, "Unknown shelf #{shelf.inspect}" unless SHELVES.include?(shelf)

      title = CsvText.clean(r["title"])
      raise ArgumentError, "Missing Title" if title.empty?

      CsvRow.new(
        goodreads_book_id: book_id(r["book id"]),
        title:,
        author: text(r["author"]),
        additional_authors: list(r["additional authors"]),
        isbn: isbn(r["isbn"]),
        isbn13: isbn(r["isbn13"]),
        avg_rating: decimal(r["average rating"]),
        num_pages: integer(r["number of pages"])&.then { |n| n.positive? ? n : nil },
        year_published: integer(r["year published"]),
        original_publication_year: integer(r["original publication year"]),
        my_rating: integer(r["my rating"])&.then { |n| (1..5).cover?(n) ? n : nil },
        exclusive_shelf: shelf,
        shelves: list(r["bookshelves"]),
        date_read: date(r["date read"]),
        date_added: date(r["date added"]),
        read_count: integer(r["read count"]) || 0,
        review: text(r["my review"])
      )
    end

    def book_id(value)
      id = unwrap(value)
      raise ArgumentError, "Missing Book Id" if id.empty?
      raise ArgumentError, "Invalid Book Id #{id.inspect}" unless id.match?(/\A\d+\z/)

      id
    end

    # Goodreads wraps ISBNs as ="0441172717" to stop spreadsheets mangling them.
    def unwrap(value) = CsvText.clean(value).delete_prefix("=").delete('"').strip

    def isbn(value) = unwrap(value).presence

    def text(value) = CsvText.trim(value).presence

    def list(value) = CsvText.clean(value).split(",").map(&:strip).compact_blank

    # Accepts "4" and spreadsheet-style "4.0"; anything else is an error for the row.
    def integer(value)
      str = CsvText.clean(value)
      return if str.empty?

      Integer(str.sub(/\.0+\z/, ""), 10)
    end

    def decimal(value)
      str = CsvText.clean(value)
      return if str.empty?

      BigDecimal(str).round(2)
    rescue ArgumentError
      raise ArgumentError, "Invalid Average Rating #{str.inspect}"
    end

    def date(value)
      str = CsvText.clean(value)
      return if str.empty?

      Date.strptime(str, "%Y/%m/%d")
    rescue Date::Error
      raise ArgumentError, "Invalid date #{str.inspect}"
    end
  end
end
