class UserBook < ApplicationRecord
  belongs_to :user
  belongs_to :book

  enum :exclusive_shelf,
       { read: "read", currently_reading: "currently-reading", to_read: "to-read" },
       prefix: :shelf, validate: true

  validates :my_rating, inclusion: { in: 1..5 }, allow_nil: true
  validates :book_id, uniqueness: { scope: :user_id }
end
