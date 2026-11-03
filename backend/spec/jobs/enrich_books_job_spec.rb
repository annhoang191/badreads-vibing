require "rails_helper"

RSpec.describe EnrichBooksJob do
  let(:user) { create(:user) }
  let(:client) { instance_double(OpenLibrary::Client) }

  before { allow(OpenLibrary::Client).to receive(:new).and_return(client) }

  it "enriches only the user's unenriched books and chains ComputeInsightsJob" do
    todo = create(:user_book, user:).book
    done = create(:user_book, user:, book: create(:book, enriched_at: 1.day.ago)).book
    other = create(:user_book).book
    allow(Books::Enricher).to receive(:call)

    expect { described_class.perform_now(user.id) }.to have_enqueued_job(ComputeInsightsJob).with(user.id)

    expect(Books::Enricher).to have_received(:call).with(book: todo, client:)
    expect(Books::Enricher).not_to have_received(:call).with(book: done, client:)
    expect(Books::Enricher).not_to have_received(:call).with(book: other, client:)
  end

  it "continues past a failing book" do
    first = create(:user_book, user:).book
    second = create(:user_book, user:).book
    allow(Books::Enricher).to receive(:call).with(book: first, client:).and_raise(OpenLibrary::Client::Error)
    allow(Books::Enricher).to receive(:call).with(book: second, client:)

    expect { described_class.perform_now(user.id) }.to have_enqueued_job(ComputeInsightsJob)
    expect(Books::Enricher).to have_received(:call).with(book: second, client:)
  end

  it "is idempotent: a second run has nothing to enrich" do
    book = create(:user_book, user:).book
    allow(client).to receive_messages(edition_by_isbn: nil, search: [])

    2.times { described_class.perform_now(user.id) }

    expect(book.reload.enrichment_status).to eq("not_found")
    expect(client).to have_received(:search).once
  end

  it "discards for a missing user" do
    expect { described_class.perform_now(0) }.not_to raise_error
  end
end
