module Books
  # FR-E1/E2/E4: enrich one book from Open Library. Lookup order: ISBN13 / ISBN edition (then its
  # work), otherwise title+author search. Marks the book enriched or not_found, either way setting
  # enriched_at so it isn't retried. Client errors (network/5xx after retries) propagate and leave
  # the book untouched so a later run retries it.
  class Enricher < ApplicationService
    COVER_URL = "https://covers.openlibrary.org/b/id/%<id>d-M.jpg".freeze

    def initialize(book:, client: OpenLibrary::Client.new, normalizer: Subjects::Normalizer)
      @book = book
      @client = client
      @normalizer = normalizer
    end

    def call
      found = lookup_by_isbn || lookup_by_search
      found ? apply(found) : @book.update!(enrichment_status: :not_found, enriched_at: Time.current)
      @book
    end

    private

    # Normalised view of whatever source matched.
    Match = Data.define(:work_key, :subjects, :cover_id, :pages, :year)
    private_constant :Match

    def lookup_by_isbn
      isbn = @book.isbn13.presence || @book.isbn.presence
      return unless isbn

      edition = @client.edition_by_isbn(isbn)
      return unless edition&.work_key

      work = @client.work(edition.work_key)
      Match.new(work_key: edition.work_key, subjects: work&.subjects || [],
                cover_id: work&.cover_id || edition.cover_id, pages: edition.number_of_pages,
                year: work&.first_publish_year)
    end

    def lookup_by_search
      result = @client.search(title: @book.title, author: @book.author, limit: 1).first
      return unless result&.work_key

      Match.new(work_key: result.work_key, subjects: result.subjects, cover_id: result.cover_id,
                pages: result.number_of_pages_median, year: result.first_publish_year)
    end

    def apply(match)
      attrs = { enrichment_status: :enriched, enriched_at: Time.current,
                subjects: @normalizer.call(subjects: match.subjects, exclude: [ @book.title ]) }
      attrs[:open_library_work_key] = match.work_key unless key_taken?(match.work_key)
      attrs[:cover_url] = format(COVER_URL, id: match.cover_id) if match.cover_id
      attrs[:num_pages] = match.pages if @book.num_pages.nil? && match.pages.to_i.positive?
      attrs[:original_publication_year] = match.year if @book.original_publication_year.nil? && match.year
      @book.update!(attrs)
    end

    def key_taken?(key)
      Book.where(open_library_work_key: key).where.not(id: @book.id).exists?
    end
  end
end
