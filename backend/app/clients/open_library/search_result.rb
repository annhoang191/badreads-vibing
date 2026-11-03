module OpenLibrary
  # One doc from /search.json.
  SearchResult = Data.define(:work_key, :title, :author, :first_publish_year, :cover_id, :subjects,
                             :number_of_pages_median, :ratings_average, :ratings_count)
end
