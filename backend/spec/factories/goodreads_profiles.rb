FactoryBot.define do
  factory :goodreads_profile do
    user
    sequence(:goodreads_user_id) { |n| (1000 + n).to_s }
    rss_enabled { false }
  end
end
