# Worked example: CSV import (SPEC §3.2)

This shows how the patterns compose for one feature. It's a sketch to copy the shape from: check names and columns against `SPEC.md` and the real schema before you use it.

```
POST /api/v1/imports
  ImportsController#create
    Imports::CsvUpload (form)            validate file size + header
    Import.create!(status: :pending)
    ImportCsvJob.perform_later(id)       → 202 + ImportSerializer
ImportCsvJob#perform
  Imports::ProcessCsv (service)          status transitions, error capture
    Goodreads::CsvParser (service)       file → [Goodreads::CsvRow] (value objects)
    Imports::Upserter (service)          upsert_all books + user_books → stats
  EnrichBooksJob / ComputeInsightsJob    queued on success
GET /api/v1/imports/:id                  polled by the frontend
```

## Controller
```ruby
module Api
  module V1
    class ImportsController < BaseController
      def create
        upload = Imports::CsvUpload.new(file: params.require(:file))
        upload.validate!
        import = current_user.imports.create!(source: :csv, status: :pending, filename: upload.filename)
        import.csv.attach(upload.file)
        ImportCsvJob.perform_later(import.id)
        render json: ImportSerializer.new(import).serialize, status: :accepted
      end

      def show
        render json: ImportSerializer.new(current_user.imports.find(params[:id])).serialize
      end
    end
  end
end
```

## Form object
```ruby
module Imports
  class CsvUpload
    include ActiveModel::Model

    MAX_BYTES = 10.megabytes
    REQUIRED_HEADERS = [ "Book Id", "Title", "Author", "Exclusive Shelf" ].freeze

    attr_accessor :file
    validates :file, presence: true
    validate :within_size, :has_goodreads_header

    delegate :original_filename, to: :file
    alias filename original_filename

    private

    def within_size
      errors.add(:file, :too_large) if file && file.size > MAX_BYTES
    end

    def has_goodreads_header
      return unless file
      header = CSV.parse_line(file.open(&:gets).to_s) || []
      missing = REQUIRED_HEADERS - header
      errors.add(:file, "is not a Goodreads export (missing #{missing.join(', ')})") if missing.any?
    end
  end
end
```

## Value object + parser service
```ruby
module Goodreads
  CsvRow = Data.define(:goodreads_book_id, :title, :author, :isbn13, :my_rating,
                       :exclusive_shelf, :shelves, :date_read, :date_added, :read_count)

  class CsvParser < ApplicationService
    def initialize(io:) = @io = io

    def call
      rows, skipped = [], []
      CSV.new(@io, headers: true).each.with_index(2) do |r, line|
        rows << build(r)
      rescue ArgumentError, KeyError => e
        skipped << { row: line, reason: e.message }
      end
      [ rows, skipped ]
    end

    private

    def build(r)
      CsvRow.new(
        goodreads_book_id: Integer(r.fetch("Book Id")),
        title: r["Title"].strip,
        author: r["Author"].strip,
        isbn13: r["ISBN13"].to_s.delete('="').presence,
        my_rating: r["My Rating"].to_i.nonzero?,
        exclusive_shelf: r["Exclusive Shelf"],
        shelves: r["Bookshelves"].to_s.split(",").map(&:strip),
        date_read: parse_date(r["Date Read"]),
        date_added: parse_date(r["Date Added"]),
        read_count: r["Read Count"].to_i
      )
    end

    def parse_date(s) = s.present? ? Date.strptime(s, "%Y/%m/%d") : nil
  end
end
```

## Orchestrating service (status transitions live here)
```ruby
module Imports
  class ProcessCsv < ApplicationService
    def initialize(import:) = @import = import

    def call
      @import.update!(status: :processing, started_at: Time.current)
      rows, skipped = @import.csv.open { |f| Goodreads::CsvParser.call(io: f) }
      stats = Imports::Upserter.call(user: @import.user, rows:)
      @import.update!(status: :completed, finished_at: Time.current,
                      stats: stats.merge(rows_skipped: skipped.size, errors: skipped.first(50)))
      EnrichBooksJob.perform_later(@import.user_id)
    rescue StandardError => e
      @import.update!(status: :failed, error_message: e.message, finished_at: Time.current)
      raise
    ensure
      @import.csv.purge_later
    end
  end
end
```

## Job (thin, takes an ID)
```ruby
class ImportCsvJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(import_id) = Imports::ProcessCsv.call(import: Import.find(import_id))
end
```

## Serializer
```ruby
class ImportSerializer < ApplicationSerializer
  attributes :id, :source, :status, :filename, :stats, :error_message, :started_at, :finished_at
end
```

## Specs (one per layer)
```ruby
# spec/forms/imports/csv_upload_spec.rb: rejects files without Goodreads headers
# spec/services/goodreads/csv_parser_spec.rb: fixture CSV → CsvRow values; strips ="..." ISBNs
# spec/services/imports/upserter_spec.rb: running twice changes nothing (idempotent)
# spec/jobs/import_csv_job_spec.rb: expect(Imports::ProcessCsv).to receive(:call).with(import:)
# spec/requests/api/v1/imports_spec.rb: 202 + body; 422 invalid_goodreads_export; 401 without token
```
