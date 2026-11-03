FactoryBot.define do
  factory :recommendation_batch do
    user
    status { "pending" }
  end
end
