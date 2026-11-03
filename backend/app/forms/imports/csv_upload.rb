module Imports
  # Validates an uploaded Goodreads CSV before an Import is created (FR-I1, FR-I2).
  # `check!` raises the ApiError matching the first failure; `valid?`/`errors` also work.
  class CsvUpload
    include ActiveModel::Model

    MAX_BYTES = 10.megabytes
    REQUIRED_HEADERS = [ "Book Id", "Title", "Author", "Exclusive Shelf" ].freeze

    attr_accessor :file

    validate :file_present, :file_type, :file_size
    validate :goodreads_header

    def filename = file.original_filename

    def check!
      return self if valid?

      message = errors.full_messages.first
      raise ApiError::InvalidGoodreadsExport.new(message, details: { missing_headers: missing_headers }) if errors.key?(:header)

      raise ApiError::InvalidFile, message
    end

    def missing_headers
      @missing_headers ||= REQUIRED_HEADERS.reject { |h| header.include?(Goodreads::CsvText.header_key(h)) }
    end

    private

    def uploaded? = file.respond_to?(:original_filename) && file.respond_to?(:read)

    def file_present
      errors.add(:file, "is required") unless uploaded?
    end

    def file_type
      return unless uploaded?

      csv = File.extname(file.original_filename.to_s).casecmp?(".csv") || file.content_type.to_s.start_with?("text/csv")
      errors.add(:file, "must be a .csv file") unless csv
    end

    def file_size
      return unless uploaded?

      errors.add(:file, "must be at most #{MAX_BYTES / 1.megabyte} MB") if file.size > MAX_BYTES
    end

    def goodreads_header
      return if errors.any? || missing_headers.empty?

      errors.add(:header, "is not a Goodreads export (missing #{missing_headers.join(', ')})")
    end

    def header
      @header ||= begin
        text = file.read
        file.rewind
        (Goodreads::CsvReader.records(text).first || []).map { |h| Goodreads::CsvText.header_key(h) }
      rescue CSV::MalformedCSVError
        []
      end
    end
  end
end
