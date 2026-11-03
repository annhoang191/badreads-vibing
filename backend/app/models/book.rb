class Book < ApplicationRecord
  has_many :user_books, dependent: :restrict_with_exception
  has_many :recommendations, dependent: :restrict_with_exception

  enum :source, { goodreads: "goodreads", open_library: "open_library" }, validate: true
  enum :enrichment_status, { pending: "pending", enriched: "enriched", not_found: "not_found" },
       prefix: :enrichment, validate: true

  validates :title, presence: true
  validates :goodreads_book_id, uniqueness: true, allow_nil: true
  validates :open_library_work_key, uniqueness: true, allow_nil: true
end
