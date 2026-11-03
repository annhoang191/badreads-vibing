module Recommendations
  # Server-side pool of candidates for one batch. Dedupes by work key, applies exclusions,
  # scores (SPEC §4.3 step 3) and hands out stable opaque ids. The LLM only ever sees ids
  # issued here, so it can't invent books.
  class CandidatePool
    WEIGHTS = { subject: 0.55, author: 0.25, popularity: 0.10, fit: 0.10 }.freeze
    LENGTH_RANGES = { "under_200" => 0...200, "from_200_to_349" => 200...350,
                      "from_350_to_499" => 350...500, "over_500" => 500.. }.freeze

    def initialize(profile:)
      @profile = profile
      @by_work_key = {}
      @seq = 0
    end

    # raw: hashes with :work_key, :title, :author, :year, :raw_subjects, :pages, :cover_id, :ratings_count
    # Returns the newly added candidates.
    def add(raws)
      added = raws.filter_map { |raw| admit(raw) }
      rescore!
      added.map { |c| @by_work_key[c.work_key] }
    end

    def size = @by_work_key.size
    def find(id) = @by_work_key.values.find { |c| c.id == id }
    def top(n) = @by_work_key.values.sort_by { |c| [ -c.pre_score, c.id ] }.first(n)

    private

    def admit(raw)
      key = raw[:work_key]
      return if key.blank? || raw[:title].blank? || raw[:author].blank? || raw[:cover_id].blank?
      return if @by_work_key.key?(key)
      return if @profile.excluded_work_keys.include?(key)
      return if @profile.excluded_book_keys.include?(BookKey.for(raw[:title], raw[:author]))

      @by_work_key[key] = Candidate.new(
        id: "c#{@seq += 1}", work_key: key, title: raw[:title], author: raw[:author], year: raw[:year],
        subjects: Subjects::Normalizer.call(subjects: raw[:raw_subjects], exclude: [ raw[:title] ]), pages: raw[:pages],
        cover_id: raw[:cover_id], ratings_count: raw[:ratings_count],
        liked_author: @profile.top_authors.include?(raw[:author]), pre_score: 0.0
      )
    end

    def rescore!
      max_pop = @by_work_key.values.filter_map(&:ratings_count).max.to_i
      @by_work_key.transform_values! { |c| c.with(pre_score: score(c, max_pop).round(4)) }
    end

    def score(c, max_pop)
      subject = [ c.subjects.sum { |s| @profile.affinity_for(s) }, 1.0 ].min
      author = c.liked_author ? 1.0 : 0.0
      popularity = c.ratings_count && max_pop.positive? ? Math.log(1 + c.ratings_count) / Math.log(1 + max_pop) : 0.5
      WEIGHTS[:subject] * subject + WEIGHTS[:author] * author +
        WEIGHTS[:popularity] * popularity + WEIGHTS[:fit] * fit(c)
    end

    def fit(c)
      length = c.pages && (range = LENGTH_RANGES[@profile.length_bucket]) ? (range.cover?(c.pages) ? 1.0 : 0.0) : 0.5
      decade = c.year && @profile.decades.any? ? (@profile.decades.include?(c.year / 10 * 10) ? 1.0 : 0.0) : 0.5
      (length + decade) / 2
    end
  end
end
