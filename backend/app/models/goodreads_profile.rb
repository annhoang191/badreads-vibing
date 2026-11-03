class GoodreadsProfile < ApplicationRecord
  belongs_to :user

  validates :goodreads_user_id, presence: true
  validates :user_id, uniqueness: true
end
