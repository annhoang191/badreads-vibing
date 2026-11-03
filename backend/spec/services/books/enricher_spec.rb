require "rails_helper"

RSpec.describe Books::Enricher do
  let(:client) { instance_double(OpenLibrary::Client) }
  let(:book) { create(:book, title: "Dune", author: "Frank Herbert", isbn13: "9780441172719", num_pages: nil) }

  def edition(**o) = OpenLibrary::Edition.new(**{ key: "/books/OL1M", work_key: "/works/OL1W", number_of_pages: 535, cover_id: 7, publish_year: 1990 }.merge(o))

  def work(**o)
    OpenLibrary::Work.new(**{ key: "/works/OL1W", title: "Dune", subjects: [ "Fiction", "Sci-fi", "nyt:x" ], cover_id: 8,
                              first_publish_year: 1965 }.merge(o))
  end

  it "enriches via ISBN13 then the work" do
    allow(client).to receive_messages(edition_by_isbn: edition, work:)

    described_class.call(book:, client:)

    expect(client).to have_received(:edition_by_isbn).with("9780441172719")
    expect(book.reload).to have_attributes(
      open_library_work_key: "/works/OL1W", subjects: [ "science fiction" ], enrichment_status: "enriched",
      cover_url: "https://covers.openlibrary.org/b/id/8-M.jpg", num_pages: 535, original_publication_year: 1965
    )
    expect(book.enriched_at).to be_present
  end

  it "falls back to the ISBN10 when there is no ISBN13" do
    book.update!(isbn13: nil, isbn: "0441172717")
    allow(client).to receive_messages(edition_by_isbn: edition, work:)

    described_class.call(book:, client:)

    expect(client).to have_received(:edition_by_isbn).with("0441172717")
  end

  it "falls back to search when the ISBN is unknown" do
    result = OpenLibrary::SearchResult.new(work_key: "/works/OL9W", title: "Dune", author: "Frank Herbert",
                                           first_publish_year: 1965, cover_id: 3, subjects: [ "Epic fantasy" ],
                                           number_of_pages_median: 400, ratings_average: 4.0, ratings_count: 10)
    allow(client).to receive_messages(edition_by_isbn: nil, search: [ result ])

    described_class.call(book:, client:)

    expect(client).to have_received(:search).with(title: "Dune", author: "Frank Herbert", limit: 1)
    expect(book.reload).to have_attributes(open_library_work_key: "/works/OL9W", subjects: [ "fantasy" ], num_pages: 400)
  end

  it "searches directly when the book has no ISBN" do
    book.update!(isbn13: nil, isbn: nil)
    allow(client).to receive(:search).and_return([])

    described_class.call(book:, client:)

    expect(client).to have_received(:search)
  end

  it "marks not_found when nothing matches" do
    allow(client).to receive_messages(edition_by_isbn: nil, search: [])

    described_class.call(book:, client:)

    expect(book.reload).to have_attributes(enrichment_status: "not_found", open_library_work_key: nil)
    expect(book.enriched_at).to be_present
  end

  it "preserves existing num_pages and original_publication_year" do
    book.update!(num_pages: 688, original_publication_year: 1964)
    allow(client).to receive_messages(edition_by_isbn: edition, work:)

    described_class.call(book:, client:)

    expect(book.reload).to have_attributes(num_pages: 688, original_publication_year: 1964)
  end

  it "skips the work key when another book already holds it" do
    create(:book, open_library_work_key: "/works/OL1W")
    allow(client).to receive_messages(edition_by_isbn: edition, work:)

    expect { described_class.call(book:, client:) }.not_to raise_error
    expect(book.reload).to have_attributes(open_library_work_key: nil, enrichment_status: "enriched",
                                           subjects: [ "science fiction" ])
  end

  it "propagates client errors without marking the book enriched" do
    allow(client).to receive(:edition_by_isbn).and_raise(OpenLibrary::Client::Error)

    expect { described_class.call(book:, client:) }.to raise_error(OpenLibrary::Client::Error)
    expect(book.reload.enriched_at).to be_nil
  end
end
