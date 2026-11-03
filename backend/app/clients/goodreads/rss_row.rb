module Goodreads
  # CsvRow plus cover_url, which only the RSS feed provides. Duck-types as an Upserter row.
  class RssRow < Data.define(*CsvRow.members, :cover_url)
    BOOK_KEYS = %i[goodreads_book_id title author additional_authors isbn isbn13 avg_rating
                   num_pages year_published original_publication_year cover_url].freeze
    USER_BOOK_KEYS = %i[exclusive_shelf shelves my_rating date_read date_added read_count review].freeze

    def book_attributes = to_h.slice(*BOOK_KEYS)
    def user_book_attributes = to_h.slice(*USER_BOOK_KEYS)
  end
end
