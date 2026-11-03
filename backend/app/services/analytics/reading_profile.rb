module Analytics
  # Builds the v1 insights snapshot (SPEC 4.1 "Exact snapshot shape (v1)", 4.2 subject affinity).
  # Two queries (the user's shelvings joined to books); everything else is in-memory aggregation,
  # which is fine for the v1 ceiling of 10,000 books per user. Returns a Hash with symbol keys.
  #
  # Choices where the spec is silent:
  # - Undated / unknown buckets (`year: nil`, `decade: nil`) are only emitted when non-empty.
  # - avg_rating of 0 (Goodreads' "no ratings") counts as missing for rating_vs_crowd.
  # - pace.best_month is the best month over all dated books, ties going to the most recent.
  # - top_subjects drop subjects whose affinity weight is 0.
  class ReadingProfile < ApplicationService
    VERSION = 1
    COLUMNS = %i[user_books.book_id user_books.exclusive_shelf user_books.my_rating user_books.date_read
                 user_books.date_added user_books.read_count books.title books.author books.num_pages
                 books.year_published books.original_publication_year books.avg_rating books.subjects
                 books.enrichment_status].freeze

    Row = Struct.new(:book_id, :shelf, :rating, :date_read, :date_added, :read_count, :title, :author, :pages,
                     :year_published, :original_year, :avg_rating, :subjects, :enrichment_status)

    def initialize(user:)
      @user = user
      @today = Date.current
    end

    def call
      @rows = @user.user_books.joins(:book).pluck(*COLUMNS).map { |values| Row.new(*values) }
      @read = @rows.select { |r| r.shelf == "read" }
      @rated = @read.select(&:rating)
      @average_rating = mean(@rated.map(&:rating))

      {
        version: VERSION,
        computed_at: Time.current.iso8601(3),
        coverage: coverage,
        metrics: {
          totals: totals,
          books_per_year: books_per_year,
          books_per_month: books_per_month,
          pages_per_year: pages_per_year,
          rating_distribution: rating_distribution,
          average_rating: @average_rating,
          rating_vs_crowd: rating_vs_crowd,
          top_authors: top_authors,
          top_subjects: top_subjects,
          length_buckets: length_buckets,
          publication_decades: publication_decades,
          pace: pace,
          rereads: rereads,
          tbr: tbr
        }
      }
    end

    private

    def coverage
      {
        read_total: @read.size,
        dated: dated.size,
        with_pages: @read.count(&:pages),
        rated: @rated.size,
        enriched: @read.count { |r| r.enrichment_status == "enriched" }
      }
    end

    def dated = @dated ||= @read.select(&:date_read)

    def totals
      {
        read: @read.size,
        currently_reading: @rows.count { |r| r.shelf == "currently_reading" },
        to_read: @rows.count { |r| r.shelf == "to_read" },
        pages_read: @read.sum { |r| r.pages.to_i }
      }
    end

    def books_per_year
      counts = dated.group_by { |r| r.date_read.year }.transform_values(&:size).sort.map do |year, count|
        { year:, count: }
      end
      undated = @read.size - dated.size
      counts << { year: nil, count: undated } if undated.positive?
      counts
    end

    def books_per_month
      counts = dated.map { |r| month_key(r.date_read) }.tally
      last_months(24).map { |m| { month: m, count: counts.fetch(m, 0) } }
    end

    def pages_per_year
      dated.select(&:pages).group_by { |r| r.date_read.year }.sort.map do |year, rows|
        { year:, pages: rows.sum(&:pages) }
      end
    end

    def rating_distribution
      dist = (1..5).to_h { |n| [ n.to_s, 0 ] }
      @rated.each { |r| dist[r.rating.to_s] += 1 }
      dist.merge("unrated" => @read.size - @rated.size)
    end

    def rating_vs_crowd
      diffs = @rated.select { |r| r.avg_rating&.positive? }.map do |r|
        { book_id: r.book_id, title: r.title, author: r.author, my_rating: r.rating,
          avg_rating: r.avg_rating.to_f, diff: (r.rating - r.avg_rating.to_f).round(2) }
      end
      {
        mean_diff: mean(diffs.pluck(:diff)),
        higher: diffs.select { |d| d[:diff].positive? }.sort_by { |d| [ -d[:diff], d[:title] ] }.first(5),
        lower: diffs.select { |d| d[:diff].negative? }.sort_by { |d| [ d[:diff], d[:title] ] }.first(5)
      }
    end

    def top_authors
      @read.select(&:author).group_by(&:author).map do |author, rows|
        { author:, count: rows.size, mean_rating: mean(rows.filter_map(&:rating)) }
      end.sort_by { |a| [ -a[:count], a[:author] ] }.first(10)
    end

    # weight = max((my_rating - user_mean) + 1, 0), summed per subject, top normalised to 1.0.
    def top_subjects
      weights = Hash.new(0.0)
      counts = Hash.new(0)
      @read.each do |r|
        next unless r.enrichment_status == "enriched"

        subjects = Array(r.subjects).uniq
        subjects.each { |s| counts[s] += 1 }
        next unless r.rating

        affinity = [ (r.rating - @average_rating) + 1, 0 ].max
        subjects.each { |s| weights[s] += affinity }
      end
      top = weights.values.max
      return [] unless top&.positive?

      weights.select { |_, w| w.positive? }
             .sort_by { |s, w| [ -w, -counts[s], s ] }.first(15)
             .map { |s, w| { subject: s, weight: (w / top).round(4), count: counts[s] } }
    end

    def length_buckets
      buckets = { under_200: 0, from_200_to_349: 0, from_350_to_499: 0, over_500: 0, unknown: 0 }
      @read.each do |r|
        key = case r.pages
        when nil then :unknown
        when ...200 then :under_200
        when 200...350 then :from_200_to_349
        when 350...500 then :from_350_to_499
        else :over_500
        end
        buckets[key] += 1
      end
      buckets
    end

    def publication_decades
      years = @read.map { |r| r.original_year || r.year_published }
      known = years.compact.map { |y| (y / 10) * 10 }.tally.sort.map { |decade, count| { decade:, count: } }
      unknown = years.count(nil)
      known << { decade: nil, count: unknown } if unknown.positive?
      known
    end

    def pace
      window = last_months(12)
      in_window = dated.count { |r| window.include?(month_key(r.date_read)) }
      best = dated.map { |r| month_key(r.date_read) }.tally.max_by { |month, count| [ count, month ] }
      {
        books_per_month_12m: (in_window / 12.0).round(2),
        best_month: best && { month: best[0], count: best[1] }
      }
    end

    def rereads
      @rows.select { |r| r.read_count.to_i > 1 }.sort_by { |r| [ -r.read_count, r.title ] }.map do |r|
        { book_id: r.book_id, title: r.title, author: r.author, read_count: r.read_count }
      end
    end

    def tbr
      queue = @rows.select { |r| r.shelf == "to_read" }
      oldest = queue.sort_by { |r| [ r.date_added ? 0 : 1, r.date_added || @today, r.title ] }.first(5)
      {
        size: queue.size,
        oldest: oldest.map do |r|
          { book_id: r.book_id, title: r.title, author: r.author, date_added: r.date_added&.iso8601 }
        end,
        median_age_days: median(queue.filter_map { |r| r.date_added && (@today - r.date_added).to_i })
      }
    end

    def last_months(count)
      start = @today.beginning_of_month
      (count - 1).downto(0).map { |i| month_key(start << i) }
    end

    def month_key(date) = date.strftime("%Y-%m")

    def mean(values) = values.empty? ? nil : (values.sum.to_f / values.size).round(2)

    def median(values)
      return if values.empty?

      sorted = values.sort
      mid = sorted.size / 2
      (sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0).round
    end
  end
end
