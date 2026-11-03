module Goodreads
  # Pulls a profile's three shelves from RSS into the library (FR-R2) and records the outcome.
  # Failures never raise: the Import is marked failed and the profile's failure counter advances;
  # the third consecutive failure disables RSS (FR-R5).
  class SyncProfile < ApplicationService
    SHELVES = %w[read currently-reading to-read].freeze
    MAX_CONSECUTIVE_FAILURES = 3

    # Creates the pending import, enforcing one active import per user (FR-I9).
    def self.start_import!(profile)
      user = profile.user
      user.with_lock do
        if user.imports.where(status: %w[pending processing]).exists?
          raise ApiError::Conflict.new("An import is already in progress", code: "import_in_progress")
        end

        user.imports.create!(source: :rss, status: :pending)
      end
    end

    # import: a pending rss import created by start_import!; created here when omitted.
    def initialize(profile:, import: nil, client: RssClient.new)
      @profile = profile
      @import = import
      @client = client
    end

    def call
      @import ||= self.class.start_import!(@profile)
      @import.update!(status: :processing, started_at: Time.current)

      rows = fetch_rows
      stats = Imports::Upserter.call(user: @profile.user, rows:, source: :rss)
      @import.update!(status: :completed, stats:, finished_at: Time.current)
      @profile.update!(last_synced_at: Time.current, consecutive_failures: 0, last_error: nil)
      @import
    rescue ApiError::Conflict
      raise
    rescue StandardError => e
      Rails.error.report(e, handled: true, context: { import_id: @import&.id, profile_id: @profile.id })
      record_failure(e)
      @import
    end

    private

    def fetch_rows
      SHELVES.flat_map do |shelf|
        @client.each_item(user_id: @profile.goodreads_user_id, shelf:)
               .select(&:title)
               .map { |item| RssItemMapper.call(item, shelf:) }
      end.reverse.uniq(&:goodreads_book_id).reverse # a book on two shelves keeps the last shelf listed
    end

    def record_failure(error)
      message = error.message.truncate(500)
      @import&.update!(status: :failed, error_message: message, finished_at: Time.current)
      failures = @profile.consecutive_failures + 1
      @profile.update!(consecutive_failures: failures, last_error: message,
                       rss_enabled: @profile.rss_enabled && failures < MAX_CONSECUTIVE_FAILURES)
    end
  end
end
