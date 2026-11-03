class RecommendationBatch < ApplicationRecord
  belongs_to :user
  has_many :recommendations, dependent: :delete_all
  has_many :llm_calls, dependent: :nullify

  enum :status, { pending: "pending", processing: "processing", completed: "completed", failed: "failed" },
       prefix: true, validate: true
  enum :ranked_by, { agent: "agent", heuristic: "heuristic" }, prefix: true, validate: { allow_nil: true }
end
