require "rails_helper"

RSpec.describe Books::LibraryQuery do
  let(:user) { create(:user) }

  def add(shelf: "read", rating: 4, read: nil, added: nil, shelves: [], **book)
    create(:user_book, user:, exclusive_shelf: shelf, my_rating: rating, date_read: read, date_added: added,
                       shelves:, book: create(:book, **book))
  end

  def titles(params = {}) = described_class.call(user.user_books, params).map { |ub| ub.book.title }

  let!(:dune) { add(title: "Dune", author: "Frank Herbert", rating: 5, read: Date.new(2023, 3, 1), added: Date.new(2023, 1, 1), shelves: %w[read sci-fi], num_pages: 600) }
  let!(:emma) { add(title: "emma", author: "Jane Austen", rating: nil, read: Date.new(2024, 5, 1), added: Date.new(2024, 1, 1), shelves: %w[read classics], num_pages: 300) }
  let!(:ulysses) { add(title: "Ulysses", author: "James Joyce", shelf: "to-read", rating: nil, added: Date.new(2022, 1, 1)) }
  let!(:odd) { add(title: "100% Real_Book", author: "Someone", shelf: "currently-reading", rating: 3, read: Date.new(2023, 9, 9), added: Date.new(2025, 1, 1)) }

  it "defaults to date_read desc with nulls last" do
    expect(titles).to eq([ "emma", "100% Real_Book", "Dune", "Ulysses" ])
  end

  it "does not leak other users' books" do
    create(:user_book)
    expect(titles.size).to eq(4)
  end

  it "filters by shelf using the client's value" do
    expect(titles(shelf: "to-read")).to eq([ "Ulysses" ])
    expect(titles(shelf: "currently-reading")).to eq([ "100% Real_Book" ])
  end

  it "filters by custom tag" do
    expect(titles(tag: "sci-fi")).to eq([ "Dune" ])
  end

  it "filters by rating and unrated" do
    expect(titles(rating: "5")).to eq([ "Dune" ])
    expect(titles(rating: "unrated", sort: "title")).to eq([ "emma", "Ulysses" ])
  end

  it "filters by year read" do
    expect(titles(year: "2023")).to eq([ "100% Real_Book", "Dune" ])
  end

  it "searches title or author case-insensitively and escapes wildcards" do
    expect(titles(q: "DUNE")).to eq([ "Dune" ])
    expect(titles(q: "austen")).to eq([ "emma" ])
    expect(titles(q: "100%")).to eq([ "100% Real_Book" ])
    expect(titles(q: "%")).to eq([ "100% Real_Book" ])
    expect(titles(q: "Real_B")).to eq([ "100% Real_Book" ])
  end

  it "sorts by each whitelisted key" do
    expect(titles(sort: "date_added")).to eq([ "100% Real_Book", "emma", "Dune", "Ulysses" ])
    expect(titles(sort: "title")).to eq([ "100% Real_Book", "Dune", "emma", "Ulysses" ])
    expect(titles(sort: "my_rating").first(2)).to eq([ "Dune", "100% Real_Book" ])
    expect(titles(sort: "num_pages").first(2)).to eq([ "Dune", "emma" ])
  end

  it "ignores invalid filter and sort values" do
    params = { shelf: "bogus", rating: "9", year: "abc", sort: "id; drop table", q: " ", tag: "" }

    expect(titles(params)).to eq(titles)
    expect(titles(rating: "x", year: "0000")).to eq(titles)
  end
end
