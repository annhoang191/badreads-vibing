require "rails_helper"

RSpec.describe Goodreads::RssClient do
  subject(:client) { described_class.new }

  let(:url) { "https://www.goodreads.com/review/list_rss/1001" }
  let(:page1) { file_fixture("goodreads_rss_read_page1.xml").read }
  let(:page2) { file_fixture("goodreads_rss_read_page2.xml").read }

  def stub_page(page, body, status: 200)
    stub_request(:get, url).with(query: { shelf: "read", page: page }).to_return(status:, body:)
  end

  describe "#fetch_page" do
    it "parses items from the feed" do
      stub_page(1, page1)
      items = client.fetch_page(user_id: "1001", shelf: "read", page: 1)

      expect(items.size).to eq(2)
      expect(items.first).to have_attributes(
        book_id: "234225", title: "Dune", author_name: "Frank Herbert", isbn: "0441172717", user_rating: "5",
        user_shelves: "sci-fi, favorites", average_rating: "4.27", book_published: "1965", num_pages: "604",
        image_url: "https://i.gr-assets.com/images/S/compressed.photo/dune_large.jpg"
      )
      expect(items.last).to have_attributes(isbn: nil, user_read_at: nil, num_pages: nil, user_shelves: nil)
    end

    it "sends a User-Agent" do
      stub_page(1, page1)
      client.fetch_page(user_id: "1001", shelf: "read")
      expect(WebMock).to have_requested(:get, url).with(query: hash_including(shelf: "read"),
                                                        headers: { "User-Agent" => /Shelfsight/ })
    end

    it "raises ProfileNotPublic on 404" do
      stub_page(1, "Not found", status: 404)
      expect { client.fetch_page(user_id: "1001", shelf: "read") }.to raise_error(described_class::ProfileNotPublic)
    end

    it "raises ProfileNotPublic on 403" do
      stub_page(1, "", status: 403)
      expect { client.fetch_page(user_id: "1001", shelf: "read") }.to raise_error(described_class::ProfileNotPublic)
    end

    it "raises ProfileNotPublic when the response is HTML" do
      stub_page(1, "<!DOCTYPE html><html><body><p>Sign in<br></body></html>")
      expect { client.fetch_page(user_id: "1001", shelf: "read") }.to raise_error(described_class::ProfileNotPublic)
    end

    it "retries 5xx responses" do
      stub_request(:get, url).with(query: { shelf: "read", page: 1 })
                             .to_return({ status: 503 }, { status: 200, body: page1 })
      allow_any_instance_of(Faraday::Retry::Middleware).to receive(:sleep)
      expect(client.fetch_page(user_id: "1001", shelf: "read").size).to eq(2)
    end
  end

  describe "#each_item" do
    it "paginates until an empty page" do
      stub_page(1, page1)
      stub_page(2, page2)

      expect(client.each_item(user_id: "1001", shelf: "read").map(&:book_id)).to eq(%w[234225 999001])
      expect(WebMock).not_to have_requested(:get, url).with(query: { shelf: "read", page: 3 })
    end
  end
end
