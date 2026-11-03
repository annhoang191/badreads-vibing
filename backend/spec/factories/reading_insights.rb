FactoryBot.define do
  factory :reading_insight do
    user
    version { 1 }
    data { {} }
    computed_at { Time.current }
  end
end
