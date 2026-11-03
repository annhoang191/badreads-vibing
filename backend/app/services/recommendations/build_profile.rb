module Recommendations
  class BuildProfile < ApplicationService
    MIN_RATED = 10

    def initialize(user:)
      @user = user
    end

    def call
      metrics = Analytics::ReadingProfile.call(user: @user).deep_symbolize_keys[:metrics]
      read = @user.user_books.shelf_read.joins(:book)
      rated = read.where.not(my_rating: nil)

      Profile.new(
        rated_read_count: rated.count,
        mean_rating: rated.average(:my_rating)&.to_f&.round(2),
        total_read: read.count,
        top_subjects: metrics[:top_subjects].first(8).map { |s| { subject: s[:subject], affinity: s[:weight].to_f } },
        top_authors: top_authors(rated),
        anchors: rated_books(rated.where(my_rating: 5).order(Arel.sql("date_read DESC NULLS LAST")).limit(5)),
        anti_anchors: rated_books(rated.where(my_rating: [ 1, 2 ]).order(:my_rating).limit(3)),
        length_bucket: dominant_length(metrics[:length_buckets]),
        decades: metrics[:publication_decades].reject { |d| d[:decade].nil? }.max_by(2) { |d| d[:count] }.map { |d| d[:decade] },
        excluded_work_keys: excluded_work_keys,
        excluded_book_keys: excluded_book_keys
      )
    end

    private

    def top_authors(rated)
      rated.group("books.author").having("COUNT(*) >= 2")
           .order(Arel.sql("AVG(user_books.my_rating) DESC, COUNT(*) DESC")).limit(5).pluck("books.author").compact
    end

    def rated_books(scope)
      scope.pluck("books.title", "books.author", :my_rating).map { |t, a, r| { title: t, author: a, rating: r } }
    end

    def dominant_length(buckets)
      known = buckets.except(:unknown)
      best = known.max_by { |_, n| n }
      best && best[1].positive? ? best[0].to_s : nil
    end

    # Every shelved book (any shelf) plus every book the user dismissed before.
    def owned_or_dismissed
      Book.where(id: @user.user_books.select(:book_id))
          .or(Book.where(id: @user.recommendations.status_dismissed.select(:book_id)))
    end

    def excluded_work_keys = owned_or_dismissed.where.not(open_library_work_key: nil).pluck(:open_library_work_key).to_set
    def excluded_book_keys = owned_or_dismissed.pluck(:title, :author).to_set { |t, a| BookKey.for(t, a) }
  end
end
