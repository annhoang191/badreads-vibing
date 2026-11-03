require "faraday"
require "faraday/retry"

module OpenLibrary
  # Adapter for https://openlibrary.org (no key). Returns value objects, never raw JSON.
  # FR-E3: <= 1 req/s, identifying User-Agent, 3 retries with exponential backoff on 429/5xx.
  class Client
    BASE_URL = "https://openlibrary.org".freeze
    RETRY_STATUSES = [ 429, 500, 502, 503, 504 ].freeze

    class Error < StandardError; end

    def initialize(throttle: Throttle.shared, retry_interval: 1.0, base_url: BASE_URL)
      @throttle = throttle
      @retry_interval = retry_interval
      @base_url = base_url
    end

    # nil when the ISBN is unknown.
    def edition_by_isbn(isbn)
      data = get("/isbn/#{ERB::Util.url_encode(isbn)}.json")
      return unless data

      Edition.new(
        key: data["key"],
        work_key: data.dig("works", 0, "key"),
        number_of_pages: data["number_of_pages"],
        cover_id: positive_id(data["covers"]&.first),
        publish_year: year_from(data["publish_date"])
      )
    end

    # `key` is "/works/OL123W" or "OL123W". nil on 404.
    def work(key)
      key = "/works/#{key}" unless key.to_s.start_with?("/works/")
      data = get("#{key}.json")
      return unless data

      Work.new(
        key: data["key"], title: data["title"], subjects: Array(data["subjects"]),
        cover_id: positive_id(data["covers"]&.first), first_publish_year: year_from(data["first_publish_date"])
      )
    end

    def search(title:, author: nil, limit: 1)
      params = { title:, author:, limit:, fields: SEARCH_FIELDS }.compact_blank
      parse_search(get("/search.json", params))
    end

    # `sort=rating` ranks the author's works by popularity.
    def search_by_author(author, limit: 10)
      parse_search(get("/search.json", { author:, sort: "rating", limit:, fields: SEARCH_FIELDS }))
    end

    def subject_works(slug, limit: 30)
      data = get("/subjects/#{ERB::Util.url_encode(slug)}.json", { limit: })
      Array(data && data["works"]).map do |w|
        SubjectWork.new(
          key: w["key"], title: w["title"], author: w.dig("authors", 0, "name"), cover_id: positive_id(w["cover_id"]),
          first_publish_year: w["first_publish_year"], subjects: Array(w["subject"])
        )
      end
    end

    private

    SEARCH_FIELDS = "key,title,author_name,first_publish_year,cover_i,subject,number_of_pages_median,ratings_average,ratings_count".freeze
    private_constant :SEARCH_FIELDS

    def parse_search(data)
      Array(data && data["docs"]).map do |d|
        SearchResult.new(
          work_key: d["key"], title: d["title"], author: Array(d["author_name"]).first,
          first_publish_year: d["first_publish_year"], cover_id: positive_id(d["cover_i"]),
          subjects: Array(d["subject"]), number_of_pages_median: d["number_of_pages_median"],
          ratings_average: d["ratings_average"], ratings_count: d["ratings_count"]
        )
      end
    end

    def get(path, params = nil)
      @throttle.wait
      response = connection.get(path, params)
      return if response.status == 404
      raise Error, "Open Library #{response.status} for #{path}" unless response.success?

      response.body
    rescue Faraday::Error => e
      raise Error, "Open Library request failed: #{e.class}: #{e.message}"
    end

    def connection
      @connection ||= Faraday.new(url: @base_url) do |f|
        f.headers["User-Agent"] = "Shelfsight/0.1 (#{Rails.application.config.x.open_library_contact})"
        f.options.open_timeout = 5
        f.options.timeout = 15
        f.request :retry, max: 3, interval: @retry_interval, backoff_factor: 2,
                          retry_statuses: RETRY_STATUSES, methods: %i[get],
                          exceptions: Faraday::Retry::Middleware::DEFAULT_EXCEPTIONS + [ Faraday::ConnectionFailed ]
        f.response :json, content_type: /\bjson/
      end
    end

    def positive_id(id) = id.is_a?(Integer) && id.positive? ? id : nil

    def year_from(text) = text.to_s[/\b(\d{4})\b/, 1]&.to_i
  end
end
