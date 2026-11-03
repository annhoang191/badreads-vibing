module Recommendations
  # Fetches raw candidates from Open Library (SPEC §4.3 step 2). Individual request failures
  # are skipped so one bad subject doesn't sink the batch.
  class CandidateSource
    def initialize(client: OpenLibrary::Client.new)
      @client = client
    end

    def fetch(subjects: [], authors: [], queries: [])
      raws = []
      (subjects + queries).uniq.each do |s|
        safely { raws.concat(@client.subject_works(slug(s), limit: 30).map { |w| from_subject_work(w) }) }
      end
      authors.uniq.each do |a|
        safely { raws.concat(@client.search_by_author(a, limit: 10).map { |r| from_search(r) }) }
      end
      raws
    end

    private

    def slug(subject) = subject.to_s.downcase.strip.gsub(/[^a-z0-9]+/, "_").gsub(/\A_|_\z/, "")

    def from_subject_work(w)
      { work_key: w.key, title: w.title, author: w.author, year: w.first_publish_year,
        raw_subjects: w.subjects, pages: nil, cover_id: w.cover_id, ratings_count: nil }
    end

    def from_search(r)
      { work_key: r.work_key, title: r.title, author: r.author, year: r.first_publish_year,
        raw_subjects: r.subjects, pages: r.number_of_pages_median, cover_id: r.cover_id,
        ratings_count: r.ratings_count }
    end

    def safely
      yield
    rescue OpenLibrary::Client::Error => e
      Rails.logger.warn("[recommendations] candidate fetch skipped: #{e.message}")
    end
  end
end
