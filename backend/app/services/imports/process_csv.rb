module Imports
  # Runs one CSV import: pending -> processing -> completed | failed (FR-I3, FR-I6, FR-I7).
  # File-level problems mark the import failed instead of raising, so the job isn't retried
  # against an import that is no longer pending.
  class ProcessCsv < ApplicationService
    MAX_ERRORS = 50

    def initialize(import:)
      @import = import
    end

    def call
      @import.update!(status: :processing, started_at: Time.current)
      raise ArgumentError, "No CSV file attached" unless @import.csv.attached?

      rows, skipped, warnings = Goodreads::CsvParser.call(io: @import.csv.download)
      stats = Imports::Upserter.call(user: @import.user, rows:, source: :csv)
      stats = stats.merge(rows_total: rows.size + skipped.size, rows_skipped: skipped.size,
                          errors: skipped.first(MAX_ERRORS), warnings:)
      @import.update!(status: :completed, stats:, finished_at: Time.current)
      after_complete
      @import
    rescue StandardError => e
      Rails.error.report(e, handled: true, context: { import_id: @import.id })
      @import.update!(status: :failed, error_message: e.message.truncate(500), finished_at: Time.current)
      @import
    ensure
      @import.csv.purge if @import.csv.attached?
    end

    private

    # FR-I8 / FR-N2: stats appear right away; enrichment then recomputes them with subjects.
    def after_complete
      user_id = @import.user_id
      ComputeInsightsJob.perform_later(user_id)
      EnrichBooksJob.perform_later(user_id)
    end
  end
end
