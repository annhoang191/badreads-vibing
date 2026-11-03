require "rails_helper"

RSpec.describe SyncRssJob do
  let(:profile) { create(:goodreads_profile, rss_enabled: true) }

  it "delegates to SyncProfile" do
    allow(Goodreads::SyncProfile).to receive(:call)
    described_class.perform_now(profile.id)
    expect(Goodreads::SyncProfile).to have_received(:call).with(profile:, import: nil)
  end

  it "passes a pre-created import" do
    import = create(:import, source: "rss", user: profile.user)
    allow(Goodreads::SyncProfile).to receive(:call)
    described_class.perform_now(profile.id, import.id)
    expect(Goodreads::SyncProfile).to have_received(:call).with(profile:, import:)
  end

  it "skips quietly when an import is in progress" do
    create(:import, user: profile.user, status: "processing")
    expect { described_class.perform_now(profile.id) }.not_to raise_error
    expect(profile.user.imports.count).to eq(1)
  end

  it "discards a missing profile" do
    expect { described_class.perform_now(0) }.not_to raise_error
  end
end
