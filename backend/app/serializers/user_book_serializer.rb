class UserBookSerializer < ApplicationSerializer
  attributes :id, :shelves, :my_rating, :date_read, :date_added, :read_count

  # The enum getter returns the key ("to_read"); the API exposes the stored value ("to-read").
  attribute(:exclusive_shelf) { |user_book| UserBook.exclusive_shelves.fetch(user_book.exclusive_shelf) }

  one :book, resource: BookSummarySerializer
end
