class Recommendation < ApplicationRecord
  belongs_to :recommendation_batch
  belongs_to :user
  belongs_to :book

  enum :status, { new: "new", saved: "saved", dismissed: "dismissed" }, prefix: true, validate: true

  validates :position, inclusion: { in: 1..10 }
  validates :book_id, uniqueness: { scope: :recommendation_batch_id }
end
