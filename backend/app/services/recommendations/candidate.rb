module Recommendations
  # A book we might recommend. `id` is the opaque reference shown to the LLM ("c17").
  Candidate = Data.define(:id, :work_key, :title, :author, :year, :subjects, :pages, :cover_id,
                          :ratings_count, :liked_author, :pre_score) do
    def cover_url = cover_id && "https://covers.openlibrary.org/b/id/#{cover_id}-M.jpg"

    def to_prompt
      { id:, title:, author:, year:, pages:, subjects: subjects.first(8) }
    end
  end
end
