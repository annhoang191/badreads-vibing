class ScheduleRssSyncsJob < ApplicationJob
  queue_as :default

  def perform
    GoodreadsProfile.where(rss_enabled: true).find_each { |profile| SyncRssJob.perform_later(profile.id) }
  end
end
