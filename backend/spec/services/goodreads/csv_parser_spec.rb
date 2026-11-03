require "rails_helper"

RSpec.describe Goodreads::CsvParser do
  HEADER = "Book Id,Title,Author,Additional Authors,ISBN,ISBN13,My Rating,Average Rating,Number of Pages," \
           "Year Published,Original Publication Year,Date Read,Date Added,Bookshelves,Exclusive Shelf,My Review,Read Count".freeze

  def parse(body, bom: false)
    text = "#{bom ? "﻿" : ''}#{HEADER}\n#{body}"
    described_class.call(io: StringIO.new(text))
  end

  describe "the sample export" do
    let(:path) { file_fixture("goodreads_export.csv") }

    it "parses 24 valid rows and skips the row with a blank Book Id" do
      rows, skipped = described_class.call(io: File.open(path))

      expect(rows.size).to eq(24)
      expect(skipped.size).to eq(1)
      expect(skipped.first[:reason]).to eq("Missing Book Id")
      expect(rows).to all(be_a(Goodreads::CsvRow))
      expect(rows.first).to have_attributes(title: "Dune", isbn13: "9780441172719", my_rating: 5)
    end
  end

  it "unwraps ISBNs, converts blanks to nil and parses numbers and dates" do
    rows, = parse(%(1,"Dune (Dune, #1)",Frank Herbert,"A, B","=""0441172717""","=""""",0,4.275,0,1990,,2023/03/14,,"read, sci-fi",read,,0\n))
    row = rows.first

    expect(row).to have_attributes(
      goodreads_book_id: "1", title: "Dune (Dune, #1)", isbn: "0441172717", isbn13: nil, my_rating: nil,
      num_pages: nil, year_published: 1990, original_publication_year: nil,
      date_read: Date.new(2023, 3, 14), date_added: nil, shelves: %w[read sci-fi],
      additional_authors: %w[A B], read_count: 0, avg_rating: BigDecimal("4.28")
    )
  end

  it "handles a UTF-8 BOM before the first header" do
    rows, skipped = parse("1,Dune,Frank Herbert,,,,5,4.2,10,1990,1965,,2023/01/01,read,read,,1\n", bom: true)

    expect(skipped).to be_empty
    expect(rows.first.goodreads_book_id).to eq("1")
  end

  it "keeps multi-line quoted fields and CRLF line endings" do
    rows, = parse("1,Dune,Frank,,,,5,,,,,,,read,read,\"Line one\nline two\",1\r\n2,Emma,Jane,,,,,,,,,,,,to-read,,0\r\n")

    expect(rows.map(&:goodreads_book_id)).to eq(%w[1 2])
    expect(rows.first.review).to eq("Line one\nline two")
  end

  it "skips invalid rows with a reason and keeps going" do
    rows, skipped = parse(<<~CSV)
      ,No id,Anon,,,,,,,,,,,,read,,0
      abc,Bad id,Anon,,,,,,,,,,,,read,,0
      3,Bad date,Anon,,,,,,,,,2023-13-45,,,read,,0
      4,Bad shelf,Anon,,,,,,,,,,,,wishlist,,0
      5,Fine,Anon,,,,,,,,,,,,read,,0
    CSV

    expect(rows.map(&:goodreads_book_id)).to eq([ "5" ])
    expect(skipped.map { |s| s[:row] }).to eq([ 2, 3, 4, 5 ])
    expect(skipped.map { |s| s[:reason] }).to include("Missing Book Id", /Invalid Book Id/, /Invalid date/, /Unknown shelf/)
  end
end
