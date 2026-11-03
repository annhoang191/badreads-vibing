class BookSummarySerializer < ApplicationSerializer
  attributes :id, :title, :author, :num_pages, :year_published, :cover_url

  attribute(:avg_rating) { |book| book.avg_rating&.to_f }
end
