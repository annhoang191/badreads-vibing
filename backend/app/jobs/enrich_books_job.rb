# Enriches a user's unenriched books sequentially (the client throttles to 1 req/s), then
# recomputes insights (FR-N2). Idempotent: only books with enriched_at IS NULL are touched, and a
# book that fails (network) is skipped this run and retried next time.
class EnrichBooksJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  BATCH_SIZE = 50

  def perform(user_id)
    user = User.find(user_id)
    client = OpenLibrary::Client.new
    pending = Book.where(id: user.user_books.select(:book_id)).where(enriched_at: nil)
    failed = 0

    pending.find_each(batch_size: BATCH_SIZE) do |book|
      Books::Enricher.call(book:, client:)
    rescue OpenLibrary::Client::Error => e
      failed += 1
      Rails.logger.warn("EnrichBooksJob book=#{book.id} failed: #{e.message}")
    end

    Rails.logger.info("EnrichBooksJob user=#{user.id} failed=#{failed}")
    ComputeInsightsJob.perform_later(user.id)
  end
end
