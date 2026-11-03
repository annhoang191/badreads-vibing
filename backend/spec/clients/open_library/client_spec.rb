require "rails_helper"

RSpec.describe OpenLibrary::Client do
  subject(:client) { described_class.new(throttle: OpenLibrary::Throttle.new(interval: 0), retry_interval: 0) }

  let(:base) { "https://openlibrary.org" }
  let(:json) { { "Content-Type" => "application/json" } }

  def stub_json(path, body, query: nil, status: 200)
    stub = stub_request(:get, "#{base}#{path}")
    stub = stub.with(query:) if query
    stub.to_return(status:, body: body.to_json, headers: json)
  end

  it "fetches an edition by ISBN with an identifying User-Agent" do
    stub_json("/isbn/9780441172719.json", { "key" => "/books/OL1M", "works" => [ { "key" => "/works/OL893415W" } ],
                                            "number_of_pages" => 535, "covers" => [ 123 ], "publish_date" => "Aug 1990" })

    edition = client.edition_by_isbn("9780441172719")

    expect(edition).to have_attributes(work_key: "/works/OL893415W", number_of_pages: 535, cover_id: 123, publish_year: 1990)
    expect(WebMock).to have_requested(:get, "#{base}/isbn/9780441172719.json")
      .with(headers: { "User-Agent" => "Shelfsight/0.1 (hquynhanh19@gmail.com)" })
  end

  it "returns nil on 404" do
    stub_request(:get, "#{base}/isbn/000.json").to_return(status: 404, body: "")
    expect(client.edition_by_isbn("000")).to be_nil
  end

  it "fetches a work" do
    stub_json("/works/OL893415W.json", { "key" => "/works/OL893415W", "title" => "Dune", "subjects" => [ "Fiction" ],
                                         "covers" => [ 55 ], "first_publish_date" => "1965" })

    expect(client.work("OL893415W")).to have_attributes(title: "Dune", subjects: [ "Fiction" ], cover_id: 55, first_publish_year: 1965)
  end

  it "searches by title and author" do
    stub_json("/search.json", { "docs" => [ { "key" => "/works/OL1W", "title" => "Dune", "author_name" => [ "Frank Herbert" ],
                                              "cover_i" => 9, "subject" => [ "Sci-fi" ], "first_publish_year" => 1965,
                                              "ratings_average" => 4.2 } ] },
              query: hash_including("title" => "Dune", "author" => "Frank Herbert", "limit" => "1"))

    result = client.search(title: "Dune", author: "Frank Herbert").first

    expect(result).to have_attributes(work_key: "/works/OL1W", author: "Frank Herbert", cover_id: 9, subjects: [ "Sci-fi" ])
  end

  it "returns no results for an empty search" do
    stub_json("/search.json", { "docs" => [] }, query: hash_including("title" => "zzz"))
    expect(client.search(title: "zzz")).to eq([])
  end

  it "lists subject works" do
    stub_json("/subjects/science_fiction.json", { "works" => [ { "key" => "/works/OL2W", "title" => "Foundation",
                                                                  "authors" => [ { "name" => "Isaac Asimov" } ], "cover_id" => 3,
                                                                  "first_publish_year" => 1951, "subject" => [ "Robots" ] } ] },
              query: hash_including("limit" => "30"))

    expect(client.subject_works("science_fiction").first).to have_attributes(title: "Foundation", author: "Isaac Asimov")
  end

  it "searches by author sorted by rating" do
    stub_json("/search.json", { "docs" => [ { "key" => "/works/OL3W", "title" => "Emma" } ] },
              query: hash_including("author" => "Jane Austen", "sort" => "rating", "limit" => "10"))

    expect(client.search_by_author("Jane Austen").map(&:title)).to eq([ "Emma" ])
  end

  it "retries on 503 and then succeeds" do
    stub_request(:get, "#{base}/works/OL1W.json")
      .to_return({ status: 503 }, { status: 503 },
                 { status: 200, body: { "key" => "/works/OL1W", "title" => "T" }.to_json, headers: json })

    expect(client.work("OL1W").title).to eq("T")
    expect(WebMock).to have_requested(:get, "#{base}/works/OL1W.json").times(3)
  end

  it "raises Error after exhausting retries" do
    stub_request(:get, "#{base}/works/OL1W.json").to_return(status: 429)

    expect { client.work("OL1W") }.to raise_error(OpenLibrary::Client::Error)
    expect(WebMock).to have_requested(:get, "#{base}/works/OL1W.json").times(4)
  end

  it "wraps timeouts" do
    stub_request(:get, "#{base}/works/OL1W.json").to_timeout

    expect { client.work("OL1W") }.to raise_error(OpenLibrary::Client::Error)
  end

  describe OpenLibrary::Throttle do
    it "sleeps to keep requests an interval apart" do
      slept = []
      throttle = described_class.new(interval: 1.0, sleeper: ->(s) { slept << s })

      throttle.wait
      throttle.wait

      expect(slept.size).to eq(1)
      expect(slept.first).to be_between(0.0, 1.0)
    end
  end
end
