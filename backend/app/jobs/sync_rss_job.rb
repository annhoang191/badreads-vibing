class SyncRssJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(profile_id, import_id = nil)
    profile = GoodreadsProfile.find(profile_id)
    import = Import.find(import_id) if import_id
    Goodreads::SyncProfile.call(profile:, import:)
  rescue ApiError::Conflict
    nil # another import is running for this user; the next schedule picks them up
  end
end
