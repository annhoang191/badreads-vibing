module RecommendationHelpers
  def rec_profile(**overrides)
    Recommendations::Profile.new(**{
      rated_read_count: 12, mean_rating: 3.8, total_read: 15,
      top_subjects: [ { subject: "science fiction", affinity: 1.0 }, { subject: "space opera", affinity: 0.6 } ],
      top_authors: [ "Ann Leckie" ],
      anchors: [ { title: "Ancillary Justice", author: "Ann Leckie", rating: 5 } ],
      anti_anchors: [ { title: "Twilight", author: "Stephenie Meyer", rating: 1 } ],
      length_bucket: "from_350_to_499", decades: [ 2010 ],
      excluded_work_keys: Set.new, excluded_book_keys: Set.new
    }.merge(overrides))
  end

  # n raw candidates; authors cycle through `authors`.
  def raw_candidates(n, authors: (1..n).map { |i| "Author #{i}" }, subjects: [ "Science fiction" ])
    (1..n).map do |i|
      { work_key: "/works/OL#{i}W", title: "Book #{i}", author: authors[(i - 1) % authors.size], year: 2015,
        raw_subjects: subjects, pages: 400, cover_id: 1000 + i, ratings_count: i * 10 }
    end
  end

  def pool_with(n, profile: rec_profile, **opts)
    Recommendations::CandidatePool.new(profile:).tap { |p| p.add(raw_candidates(n, **opts)) }
  end

  def ranking_for(pool, n = 10)
    { "recommendations" => pool.top(n).each_with_index.map do |c, i|
      { "id" => c.id, "score" => 95 - i, "reason" => "Because you loved Ancillary Justice, #{c.title} fits." }
    end }
  end
end

RSpec.configure { |c| c.include RecommendationHelpers }
