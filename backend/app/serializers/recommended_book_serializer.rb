class RecommendedBookSerializer < ApplicationSerializer
  OPEN_LIBRARY = "https://openlibrary.org".freeze

  attributes :id, :title, :author, :num_pages, :cover_url

  attribute(:year) { |book| book.original_publication_year || book.year_published }

  attribute :open_library_url do |book|
    "#{OPEN_LIBRARY}#{book.open_library_work_key}" if book.open_library_work_key.present?
  end
end
