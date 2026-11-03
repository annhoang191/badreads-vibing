FactoryBot.define do
  factory :session do
    user
    last_used_at { Time.current }
    ip_address { "127.0.0.1" }
    user_agent { "RSpec" }
  end
end
