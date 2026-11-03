module Recommendations
  # What the recommender knows about a reader (SPEC §4.3 step 1). Contains no PII:
  # titles, authors, ratings, subjects, and aggregates only.
  Profile = Data.define(
    :rated_read_count, :mean_rating, :total_read,
    :top_subjects,   # [{ subject:, affinity: }], affinity 0..1
    :top_authors,    # [String] liked authors (>= 2 reads, by mean rating)
    :anchors,        # [{ title:, author:, rating: }] recent 5★ reads
    :anti_anchors,   # [{ title:, author:, rating: }] 1–2★ reads
    :length_bucket,  # dominant bucket key, e.g. "from_350_to_499", or nil
    :decades,        # [Integer] top publication decades
    :excluded_work_keys, :excluded_book_keys # Sets — never recommend these (FR-C5)
  ) do
    def affinity_for(subject) = top_subjects.find { |s| s[:subject] == subject }&.dig(:affinity) || 0.0

    # Compact JSON for prompts (no exclusion sets).
    def to_prompt
      { read_books: total_read, rated_books: rated_read_count, mean_rating:,
        top_subjects: top_subjects.map { |s| "#{s[:subject]} (#{s[:affinity]})" },
        liked_authors: top_authors, loved_recently: anchors, disliked: anti_anchors,
        typical_length: length_bucket, favorite_decades: decades }
    end
  end
end
