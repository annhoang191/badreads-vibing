module Goodreads
  # One normalized row of a Goodreads export (see SPEC 3.2 column mapping).
  CsvRow = Data.define(
    :goodreads_book_id, :title, :author, :additional_authors, :isbn, :isbn13, :avg_rating,
    :num_pages, :year_published, :original_publication_year,
    :my_rating, :exclusive_shelf, :shelves, :date_read, :date_added, :read_count, :review
  ) do
    BOOK_KEYS = %i[goodreads_book_id title author additional_authors isbn isbn13 avg_rating
                   num_pages year_published original_publication_year].freeze
    USER_BOOK_KEYS = %i[exclusive_shelf shelves my_rating date_read date_added read_count review].freeze

    def book_attributes = to_h.slice(*BOOK_KEYS)
    def user_book_attributes = to_h.slice(*USER_BOOK_KEYS)
  end
end
