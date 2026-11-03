FactoryBot.define do
  factory :llm_call do
    task { "rank_candidates" }
    tier { "complex" }
    model { "claude-opus-5-5" }
  end
end
