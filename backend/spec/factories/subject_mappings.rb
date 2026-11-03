FactoryBot.define do
  factory :subject_mapping do
    sequence(:raw_subject) { |n| "raw subject #{n}" }
    canonical_subject { "science fiction" }
    source { "config" }
  end
end
