FactoryBot.define do
  factory :user_book do
    user
    book
    exclusive_shelf { "read" }
    my_rating { 4 }
    date_read { Date.current }
  end
end
