require "faraday"
require "faraday/retry"

module Goodreads
  # Fetches a public Goodreads shelf RSS feed. Parsing is defensive: Goodreads varies which
  # elements it includes, so every field is optional except book_id.
  class RssClient
    class ProfileNotPublic < StandardError; end

    BASE_URL = "https://www.goodreads.com".freeze
    MAX_PAGES = 50
    USER_AGENT = "Shelfsight/1.0 (personal reading tracker; RSS sync)".freeze

    def initialize(connection: nil)
      @connection = connection || build_connection
    end

    def fetch_page(user_id:, shelf:, page: 1)
      response = @connection.get("/review/list_rss/#{user_id}", shelf: shelf, page: page)
      raise ProfileNotPublic, "Goodreads returned #{response.status}" if [ 403, 404 ].include?(response.status)
      raise Faraday::ServerError, "Goodreads returned #{response.status}" unless response.success?

      parse(response.body)
    end

    def each_item(user_id:, shelf:)
      return enum_for(:each_item, user_id:, shelf:) unless block_given?

      (1..MAX_PAGES).each do |page|
        items = fetch_page(user_id:, shelf:, page:)
        break if items.empty?

        items.each { |item| yield item }
      end
    end

    private

    def build_connection
      Faraday.new(url: BASE_URL, headers: { "User-Agent" => USER_AGENT },
                  request: { open_timeout: 5, timeout: 15 }) do |f|
        f.request :retry, max: 2, interval: 0.5, backoff_factor: 2,
                          retry_statuses: [ 500, 502, 503, 504 ],
                          exceptions: Faraday::Retry::Middleware::DEFAULT_EXCEPTIONS + [ Faraday::ConnectionFailed ]
        f.adapter Faraday.default_adapter
      end
    end

    def parse(body)
      doc = Nokogiri::XML(body.to_s) { |c| c.noblanks.nonet }
      raise ProfileNotPublic, "Response is not an RSS feed" unless doc.errors.empty? && doc.at_xpath("/rss/channel")

      doc.xpath("/rss/channel/item").filter_map { |node| build_item(node) }
    end

    def build_item(node)
      book_id = text(node, "book_id")
      return if book_id.nil?

      RssItem.new(
        book_id:, title: text(node, "title"), author_name: text(node, "author_name"),
        isbn: text(node, "isbn"), user_rating: text(node, "user_rating"),
        user_read_at: text(node, "user_read_at"), user_date_added: text(node, "user_date_added"),
        user_shelves: text(node, "user_shelves"),
        image_url: text(node, "book_large_image_url") || text(node, "book_image_url"),
        average_rating: text(node, "average_rating"), book_published: text(node, "book_published"),
        num_pages: text(node, "book/num_pages")
      )
    end

    def text(node, path)
      node.at_xpath(path)&.text&.strip.presence
    end
  end
end
