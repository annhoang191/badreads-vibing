require "rails_helper"

RSpec.describe Analytics::ReadingProfile do
  let(:user) { create(:user) }
  let(:today) { Date.new(2026, 11, 15) }
  let(:metrics) { profile[:metrics] }
  let(:profile) { travel_to(today) { described_class.call(user:) } }

  def shelve(shelf: "read", rating: nil, date_read: nil, date_added: nil, read_count: 1, **book_attrs)
    book = create(:book, **book_attrs)
    create(:user_book, user:, book:, exclusive_shelf: shelf, my_rating: rating, date_read:, date_added:, read_count:)
  end

  context "with no books" do
    it "returns the full shape with empty values" do
      expect(profile.keys).to eq(%i[version computed_at coverage metrics])
      expect(profile[:coverage]).to eq(read_total: 0, dated: 0, with_pages: 0, rated: 0, enriched: 0)
      expect(metrics.keys).to eq(%i[totals books_per_year books_per_month pages_per_year rating_distribution
                                    average_rating rating_vs_crowd top_authors top_subjects length_buckets
                                    publication_decades pace rereads tbr])
      expect(metrics[:average_rating]).to be_nil
      expect(metrics[:rating_vs_crowd]).to eq(mean_diff: nil, higher: [], lower: [])
      expect(metrics[:books_per_month].size).to eq(24)
      expect(metrics[:pace]).to eq(books_per_month_12m: 0.0, best_month: nil)
      expect(metrics[:tbr]).to eq(size: 0, oldest: [], median_age_days: nil)
    end
  end

  context "with a deterministic library" do
    before do
      shelve(rating: 5, date_read: Date.new(2026, 11, 1), title: "A", author: "X", num_pages: 150, avg_rating: 4.0,
             original_publication_year: 1965, enrichment_status: "enriched", subjects: %w[space dystopia])
      shelve(rating: 3, date_read: Date.new(2026, 11, 20), title: "B", author: "X", num_pages: 200, avg_rating: 4.5,
             year_published: 2001, enrichment_status: "enriched", subjects: %w[space romance])
      shelve(rating: 4, date_read: Date.new(2025, 12, 5), title: "C", author: "Y", num_pages: 350, avg_rating: 3.0,
             original_publication_year: 1969, read_count: 3)
      shelve(rating: nil, date_read: Date.new(2023, 1, 5), title: "D", author: "Z", num_pages: 500)
      shelve(rating: 5, date_read: nil, title: "E", author: "Y", num_pages: nil, avg_rating: 2.0)
      shelve(shelf: "currently-reading", title: "F")
      shelve(shelf: "to-read", date_added: Date.new(2026, 11, 5), title: "T1")
      shelve(shelf: "to-read", date_added: Date.new(2026, 10, 16), title: "T2")
      shelve(shelf: "to-read", date_added: nil, title: "T3")
    end

    it "computes coverage and totals" do
      expect(profile[:coverage]).to eq(read_total: 5, dated: 4, with_pages: 4, rated: 4, enriched: 2)
      expect(metrics[:totals]).to eq(read: 5, currently_reading: 1, to_read: 3, pages_read: 1200)
    end

    it "buckets books per year with undated last" do
      expect(metrics[:books_per_year]).to eq([ { year: 2023, count: 1 }, { year: 2025, count: 1 },
                                               { year: 2026, count: 2 }, { year: nil, count: 1 } ])
    end

    it "zero-fills the last 24 months including the current one" do
      months = metrics[:books_per_month]
      expect(months.first).to eq(month: "2024-12", count: 0)
      expect(months.last).to eq(month: "2026-11", count: 2)
      expect(months.find { |m| m[:month] == "2025-12" }[:count]).to eq(1)
      expect(months.sum { |m| m[:count] }).to eq(3)
    end

    it "sums pages per dated year skipping null pages" do
      expect(metrics[:pages_per_year]).to eq([ { year: 2023, pages: 500 }, { year: 2025, pages: 350 },
                                               { year: 2026, pages: 350 } ])
    end

    it "reports the rating distribution with unrated separate and the mean over rated books" do
      expect(metrics[:rating_distribution]).to eq("1" => 0, "2" => 0, "3" => 1, "4" => 1, "5" => 2, "unrated" => 1)
      expect(metrics[:average_rating]).to eq(4.25)
    end

    it "compares to the crowd in both directions" do
      crowd = metrics[:rating_vs_crowd]
      expect(crowd[:mean_diff]).to eq(0.88) # (1.0 - 1.5 + 1.0 + 3.0) / 4
      expect(crowd[:higher].map { |d| d[:title] }).to eq(%w[E A C])
      expect(crowd[:higher].first).to eq(book_id: Book.find_by(title: "E").id, title: "E", author: "Y", my_rating: 5,
                                         avg_rating: 2.0, diff: 3.0)
      expect(crowd[:lower].map { |d| d[:title] }).to eq(%w[B])
      expect(crowd[:lower].first[:diff]).to eq(-1.5)
    end

    it "ranks authors by read count with mean rating" do
      expect(metrics[:top_authors]).to eq([
        { author: "X", count: 2, mean_rating: 4.0 },
        { author: "Y", count: 2, mean_rating: 4.5 },
        { author: "Z", count: 1, mean_rating: nil }
      ])
    end

    it "weights subjects by rating above the user's mean, normalised to 1.0" do
      # mean 4.25: A (5) -> 1.75 for space, dystopia; B (3) -> 0 (floored) for space, romance
      expect(metrics[:top_subjects]).to eq([
        { subject: "dystopia", weight: 1.0, count: 1 },
        { subject: "space", weight: 1.0, count: 2 }
      ].sort_by { |s| [ -s[:weight], -s[:count], s[:subject] ] })
    end

    it "buckets lengths with unknown" do
      expect(metrics[:length_buckets]).to eq(under_200: 1, from_200_to_349: 1, from_350_to_499: 1, over_500: 1,
                                             unknown: 1)
    end

    it "groups decades by original year then published year, unknown last" do
      expect(metrics[:publication_decades]).to eq([ { decade: 1960, count: 2 }, { decade: 2000, count: 1 },
                                                    { decade: nil, count: 2 } ])
    end

    it "computes pace over the last 12 months and the best month" do
      # window 2025-12..2026-11 holds 3 dated books
      expect(metrics[:pace]).to eq(books_per_month_12m: 0.25, best_month: { month: "2026-11", count: 2 })
    end

    it "lists rereads" do
      expect(metrics[:rereads].map { |r| [ r[:title], r[:read_count] ] }).to eq([ [ "C", 3 ] ])
    end

    it "summarises the TBR shelf" do
      tbr = metrics[:tbr]
      expect(tbr[:size]).to eq(3)
      expect(tbr[:oldest].map { |b| [ b[:title], b[:date_added] ] }).to eq(
        [ [ "T2", "2026-10-16" ], [ "T1", "2026-11-05" ], [ "T3", nil ] ]
      )
      expect(tbr[:median_age_days]).to eq(20) # ages 30 and 10 -> 20
    end

    it "serialises to JSON with the same keys" do
      json = JSON.parse(profile.to_json)
      expect(json["metrics"]["rating_distribution"].keys).to eq(%w[1 2 3 4 5 unrated])
      expect(json["version"]).to eq(1)
    end
  end

  it "limits lists: 5 higher, 10 authors, 15 subjects" do
    12.times do |i|
      shelve(rating: 5, date_read: today, title: "T#{i}", author: "Author#{i}", avg_rating: 1.0 + (i * 0.1),
             enrichment_status: "enriched", subjects: Array.new(20) { |j| "s#{j}" })
    end
    shelve(rating: 1, date_read: today, title: "low", author: "L", avg_rating: 4.0)

    expect(metrics[:rating_vs_crowd][:higher].size).to eq(5)
    expect(metrics[:rating_vs_crowd][:higher].first[:title]).to eq("T0")
    expect(metrics[:top_authors].size).to eq(10)
    expect(metrics[:top_subjects].size).to eq(15)
  end

  it "ignores zero crowd averages and other users' books" do
    shelve(rating: 4, date_read: today, avg_rating: 0)
    create(:user_book, my_rating: 5)

    expect(metrics[:rating_vs_crowd][:mean_diff]).to be_nil
    expect(metrics[:totals][:read]).to eq(1)
  end

  it "works on the fixture CSV" do
    rows, = Goodreads::CsvParser.call(io: file_fixture("goodreads_export.csv").read)
    Imports::Upserter.call(user:, rows:, source: :csv)

    expect(metrics[:totals][:read]).to be_positive
    expect(metrics[:rating_distribution].values.sum).to eq(metrics[:totals][:read])
  end
end
