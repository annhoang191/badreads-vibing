FactoryBot.define do
  factory :book do
    source { "goodreads" }
    sequence(:goodreads_book_id) { |n| (5000 + n).to_s }
    title { Faker::Book.title }
    author { Faker::Book.author }
    enrichment_status { "pending" }
  end
end
