module Recommendations
  # Rolling 24h generation quota (FR-C3). Failed batches count: they may have spent tokens.
  class Quota
    LIMIT = 5
    WINDOW = 24.hours

    def initialize(user:)
      @user = user
    end

    def used = window_times.size

    def remaining = [ LIMIT - used, 0 ].max

    def exhausted? = remaining.zero?

    def resets_at = exhausted? ? window_times.first + WINDOW : nil

    # Seconds until a slot frees up (only meaningful when exhausted).
    def retry_after = exhausted? ? [ (resets_at - Time.current).ceil, 1 ].max : 0

    def to_h = { limit: LIMIT, remaining:, resets_at: }

    private

    def window_times
      @window_times ||= @user.recommendation_batches
                             .where(created_at: (Time.current - WINDOW)..)
                             .order(:created_at).pluck(:created_at)
    end
  end
end
