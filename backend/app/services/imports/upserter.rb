module Imports
  # Writes parsed rows to books and user_books with upsert_all and returns the FR-I7 stats.
  #
  # Idempotent: books conflict on goodreads_book_id, user_books on (user_id, book_id), so running
  # the same rows twice creates nothing the second time. "Created" vs "updated" is decided by
  # looking up which keys already existed before the write.
  #
  # source: :csv  - a row's values overwrite stored ones (a newer export wins, including blanks).
  # source: :rss  - FR-R4: nil/empty values never overwrite; they are left out of the upsert, so
  #                 RSS only fills gaps. Rows are grouped by which columns they carry because
  #                 upsert_all needs the same column set within one statement.
  class Upserter < ApplicationService
    BATCH_SIZE = 1000

    def initialize(user:, rows:, source: :csv)
      @user = user
      @rows = rows.reverse.uniq(&:goodreads_book_id).reverse # last row wins for duplicate Book Ids
      @source = source.to_sym
    end

    def call
      ids = @rows.map(&:goodreads_book_id)
      existing_book_ids = Book.where(goodreads_book_id: ids).pluck(:goodreads_book_id).to_set

      upsert_books
      book_pk = Book.where(goodreads_book_id: ids).pluck(:goodreads_book_id, :id).to_h
      existing_shelved = @user.user_books.where(book_id: book_pk.values).pluck(:book_id).to_set

      upsert_user_books(book_pk)

      shelvings_updated = existing_shelved.size
      books_updated = existing_book_ids.size
      {
        rows_total: @rows.size,
        books_created: @rows.size - books_updated,
        books_updated: books_updated,
        shelvings_created: @rows.size - shelvings_updated,
        shelvings_updated: shelvings_updated,
        rows_skipped: 0,
        missing_from_source: missing_from_source(book_pk.values),
        errors: []
      }
    end

    private

    def upsert_books
      attrs = @rows.map { |row| row.book_attributes.merge(source: "goodreads") }
      write(Book, attrs, unique_by: :index_books_on_goodreads_book_id)
    end

    def upsert_user_books(book_pk)
      attrs = @rows.map do |row|
        row.user_book_attributes.merge(user_id: @user.id, book_id: book_pk.fetch(row.goodreads_book_id))
      end
      write(UserBook, attrs, unique_by: %i[user_id book_id])
    end

    def write(model, attrs, unique_by:)
      attrs = attrs.map { |a| a.reject { |_, v| blank_value?(v) } } if @source == :rss
      attrs.group_by(&:keys).each_value do |group|
        options = { unique_by: }
        options[:on_duplicate] = book_on_duplicate(group.first.keys) if model == Book && @source == :csv
        group.each_slice(BATCH_SIZE) { |batch| model.upsert_all(batch, **options) }
      end
    end

    # A re-import must not blank values that enrichment filled in (FR-E2): for these columns a nil
    # in the CSV keeps the stored value. Every other imported column is overwritten as before.
    ENRICHABLE_COLUMNS = %w[num_pages original_publication_year].freeze

    def book_on_duplicate(columns)
      sets = (columns.map(&:to_s) - [ "goodreads_book_id" ]).map do |col|
        quoted = Book.connection.quote_column_name(col)
        ENRICHABLE_COLUMNS.include?(col) ? "#{quoted} = COALESCE(EXCLUDED.#{quoted}, books.#{quoted})" : "#{quoted} = EXCLUDED.#{quoted}"
      end
      Arel.sql((sets + [ "updated_at = CURRENT_TIMESTAMP" ]).join(", "))
    end

    def blank_value?(value) = value.nil? || value == []

    # FR-I5: only a full export says anything about absence. Nothing is deleted.
    def missing_from_source(kept_book_ids)
      return 0 unless @source == :csv

      @user.user_books.joins(:book).where(books: { source: "goodreads" }).where.not(book_id: kept_book_ids).count
    end
  end
end
