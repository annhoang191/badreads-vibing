class User < ApplicationRecord
  has_secure_password

  # The database cascades deletes (FR-A5); :delete_all mirrors that without loading rows.
  has_many :sessions, dependent: :delete_all
  has_one :goodreads_profile, dependent: :delete
  has_many :user_books, dependent: :delete_all
  has_many :books, through: :user_books
  has_many :imports, dependent: :delete_all
  has_one :reading_insight, dependent: :delete
  has_many :recommendation_batches, dependent: :delete_all
  has_many :recommendations, dependent: :delete_all

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :password, length: { minimum: 10 }, allow_nil: true
end
