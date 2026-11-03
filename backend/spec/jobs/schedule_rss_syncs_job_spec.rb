require "rails_helper"

RSpec.describe ScheduleRssSyncsJob do
  it "enqueues a sync for each rss-enabled profile only" do
    enabled = create(:goodreads_profile, rss_enabled: true)
    create(:goodreads_profile, rss_enabled: false)

    expect { described_class.perform_now }.to have_enqueued_job(SyncRssJob).with(enabled.id).exactly(:once)
    expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(1)
  end
end
