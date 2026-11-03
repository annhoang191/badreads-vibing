class GoodreadsProfileSerializer < ApplicationSerializer
  attributes :goodreads_user_id, :rss_enabled, :last_synced_at, :last_error, :consecutive_failures
end
