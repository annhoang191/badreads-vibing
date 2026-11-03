require "rails_helper"

RSpec.describe "GET /api/v1/books", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  it "returns 401 without a token" do
    get "/api/v1/books"
    expect(response).to have_http_status(:unauthorized)
  end

  it "serializes user books with their book and pagination meta" do
    book = create(:book, title: "Dune", author: "Frank Herbert", num_pages: 688, year_published: 1990,
                         avg_rating: 4.27, cover_url: "https://example.com/c.jpg")
    ub = create(:user_book, user:, book:, exclusive_shelf: "to-read", my_rating: nil, date_read: nil,
                            date_added: Date.new(2024, 1, 2), shelves: %w[to-read sci-fi], read_count: 0)
    create(:user_book)

    get "/api/v1/books", headers: headers

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["meta"]).to eq("page" => 1, "per_page" => 25, "total" => 1, "total_pages" => 1)
    expect(body["data"].first).to eq(
      "id" => ub.id, "exclusive_shelf" => "to-read", "shelves" => %w[to-read sci-fi], "my_rating" => nil,
      "date_read" => nil, "date_added" => "2024-01-02", "read_count" => 0,
      "book" => { "id" => book.id, "title" => "Dune", "author" => "Frank Herbert", "num_pages" => 688,
                  "year_published" => 1990, "avg_rating" => 4.27, "cover_url" => "https://example.com/c.jpg" }
    )
  end

  it "returns a null avg_rating when unknown" do
    create(:user_book, user:)

    get "/api/v1/books", headers: headers

    expect(response.parsed_body["data"].first["book"]["avg_rating"]).to be_nil
  end

  it "paginates and caps per_page at 100" do
    create_list(:user_book, 3, user:)

    get "/api/v1/books", params: { per_page: 2, page: 2 }, headers: headers
    expect(response.parsed_body["data"].size).to eq(1)
    expect(response.parsed_body["meta"]).to eq("page" => 2, "per_page" => 2, "total" => 3, "total_pages" => 2)

    get "/api/v1/books", params: { per_page: 500 }, headers: headers
    expect(response.parsed_body["meta"]["per_page"]).to eq(100)
  end

  it "clamps a page past the end and tolerates junk paging params" do
    create(:user_book, user:)

    get "/api/v1/books", params: { page: 99, per_page: "abc" }, headers: headers

    expect(response.parsed_body["meta"]).to eq("page" => 1, "per_page" => 25, "total" => 1, "total_pages" => 1)
  end

  it "returns an empty page for an empty library" do
    get "/api/v1/books", headers: headers

    expect(response.parsed_body).to eq("data" => [], "meta" => { "page" => 1, "per_page" => 25, "total" => 0, "total_pages" => 1 })
  end

  it "applies filters and sort" do
    create(:user_book, user:, my_rating: 5, book: create(:book, title: "Alpha"))
    create(:user_book, user:, my_rating: 2, book: create(:book, title: "Beta"))

    get "/api/v1/books", params: { rating: 5 }, headers: headers
    expect(response.parsed_body["data"].map { |d| d["book"]["title"] }).to eq([ "Alpha" ])

    get "/api/v1/books", params: { sort: "title", q: "a" }, headers: headers
    expect(response.parsed_body["data"].map { |d| d["book"]["title"] }).to eq(%w[Alpha Beta])
  end
end
