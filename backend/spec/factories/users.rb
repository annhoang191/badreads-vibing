FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "reader#{n}@example.com" }
    password { "correct-horse-battery" }
  end
end
