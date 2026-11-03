FactoryBot.define do
  factory :import do
    user
    source { "csv" }
    status { "pending" }
    filename { "goodreads_library_export.csv" }

    trait :completed do
      status { "completed" }
      started_at { 1.minute.ago }
      finished_at { Time.current }
    end
  end
end
