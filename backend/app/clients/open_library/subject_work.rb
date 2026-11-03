module OpenLibrary
  # One work from /subjects/{slug}.json.
  SubjectWork = Data.define(:key, :title, :author, :cover_id, :first_publish_year, :subjects)
end
