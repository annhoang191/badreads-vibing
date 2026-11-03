FactoryBot.define do
  factory :recommendation do
    recommendation_batch
    user { recommendation_batch.user }
    book
    sequence(:position) { |n| ((n - 1) % 10) + 1 }
    score { 80 }
    reason { "Shares themes with books you loved." }
    status { "new" }
  end
end
