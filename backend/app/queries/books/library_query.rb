module Books
  # Filters and sorts a user's library (FR-L2, FR-L3). Invalid filter values are ignored.
  #
  #   Books::LibraryQuery.call(current_user.user_books, params)
  class LibraryQuery < ApplicationQuery
    DEFAULT_SORT = "date_read".freeze
    SORTS = {
      "date_read" => "user_books.date_read DESC NULLS LAST",
      "date_added" => "user_books.date_added DESC NULLS LAST",
      "title" => "LOWER(books.title) ASC",
      "my_rating" => "user_books.my_rating DESC NULLS LAST",
      "num_pages" => "books.num_pages DESC NULLS LAST"
    }.freeze

    def self.default_relation = UserBook.none

    def call
      scope = relation.joins(:book).includes(:book)
      scope = by_shelf(scope)
      scope = by_tag(scope)
      scope = by_rating(scope)
      scope = by_year(scope)
      scope = by_query(scope)
      scope.order(Arel.sql(SORTS.fetch(sort_key)), "user_books.id ASC")
    end

    private

    def sort_key = SORTS.key?(params[:sort].to_s) ? params[:sort].to_s : DEFAULT_SORT

    def by_shelf(scope)
      shelf = params[:shelf].to_s
      UserBook.exclusive_shelves.value?(shelf) ? scope.where(exclusive_shelf: shelf) : scope
    end

    def by_tag(scope)
      tag = params[:tag].to_s.strip
      tag.empty? ? scope : scope.where("? = ANY(user_books.shelves)", tag)
    end

    def by_rating(scope)
      rating = params[:rating].to_s
      return scope.where(my_rating: nil) if rating == "unrated"

      rating.match?(/\A[1-5]\z/) ? scope.where(my_rating: rating.to_i) : scope
    end

    def by_year(scope)
      year = params[:year].to_s
      return scope unless year.match?(/\A\d{4}\z/) && year.to_i.positive?

      scope.where(date_read: Date.new(year.to_i, 1, 1)..Date.new(year.to_i, 12, 31))
    end

    def by_query(scope)
      q = params[:q].to_s.strip
      return scope if q.empty?

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(q)}%"
      scope.where("books.title ILIKE :p OR books.author ILIKE :p", p: pattern)
    end
  end
end
