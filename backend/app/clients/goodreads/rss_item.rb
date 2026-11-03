module Goodreads
  # One <item> of a Goodreads review list feed, all values as raw strings (nil when absent).
  RssItem = Data.define(
    :book_id, :title, :author_name, :isbn, :user_rating, :user_read_at, :user_date_added,
    :user_shelves, :image_url, :average_rating, :book_published, :num_pages
  )
end
