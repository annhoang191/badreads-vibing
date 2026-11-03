require "rails_helper"

RSpec.describe Imports::ProcessCsv do
  let(:import) { create(:import) }

  def attach(content)
    import.csv.attach(io: StringIO.new(content), filename: "export.csv", content_type: "text/csv")
  end

  it "processes the file, stores stats and purges the attachment" do
    import.csv.attach(io: file_fixture("goodreads_export.csv").open, filename: "export.csv", content_type: "text/csv")

    described_class.call(import:)
    import.reload

    expect(import).to be_status_completed
    expect(import.started_at).to be_present
    expect(import.finished_at).to be_present
    expect(import.stats).to include("rows_total" => 25, "rows_skipped" => 1, "books_created" => 24,
                                    "shelvings_created" => 24, "missing_from_source" => 0)
    expect(import.stats["errors"]).to eq([ { "row" => 26, "reason" => "Missing Book Id" } ])
    expect(import.csv).not_to be_attached
    expect(import.user.user_books.count).to eq(24)
  end

  it "enqueues insights and enrichment for the user after a successful import" do
    attach("Book Id,Title,Author,Exclusive Shelf\n1,A,B,read\n")

    expect { described_class.call(import:) }
      .to have_enqueued_job(ComputeInsightsJob).with(import.user_id)
      .and have_enqueued_job(EnrichBooksJob).with(import.user_id)
  end

  it "does not enqueue follow-up jobs when the import fails" do
    attach("Book Id,Title,Author,Exclusive Shelf\n1,A,B,read\n")
    allow(Imports::Upserter).to receive(:call).and_raise(StandardError, "boom")

    expect { described_class.call(import:) }.not_to have_enqueued_job(EnrichBooksJob)
  end

  it "moves through processing before completing" do
    attach("Book Id,Title,Author,Exclusive Shelf\n1,A,B,read\n")
    seen = nil
    allow(Imports::Upserter).to receive(:call).and_wrap_original do |m, **args|
      seen = import.reload.status
      m.call(**args)
    end

    described_class.call(import:)

    expect(seen).to eq("processing")
  end

  it "caps recorded errors at 50" do
    attach("Book Id,Title,Author,Exclusive Shelf\n#{"x,A,B,read\n" * 60}")

    described_class.call(import:)

    expect(import.reload.stats).to include("rows_skipped" => 60)
    expect(import.stats["errors"].size).to eq(50)
  end

  it "marks the import failed with a message when processing blows up" do
    attach("Book Id,Title,Author,Exclusive Shelf\n1,A,B,read\n")
    allow(Imports::Upserter).to receive(:call).and_raise(StandardError, "boom")

    described_class.call(import:)
    import.reload

    expect(import).to be_status_failed
    expect(import.error_message).to eq("boom")
    expect(import.finished_at).to be_present
    expect(import.csv).not_to be_attached
  end

  it "fails when no file is attached" do
    described_class.call(import:)

    expect(import.reload).to be_status_failed
  end
end
