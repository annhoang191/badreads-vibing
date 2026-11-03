module Subagents
  # simple tier (Haiku): suggest extra subject-style themes to widen the candidate pool.
  class ExpandQueries < ApplicationService
    SCHEMA = {
      type: "object", additionalProperties: false, required: %w[queries],
      properties: { queries: { type: "array", items: { type: "string" } } }
    }.freeze

    def initialize(llm:, profile:)
      @llm = llm
      @profile = profile
    end

    def call
      p = @profile.to_prompt.slice(:top_subjects, :liked_authors, :loved_recently)
      out = @llm.json(task: :expand_queries, system: Llm::Prompt.for(:expand_queries),
                      input: p, schema: SCHEMA, max_tokens: 500)
      Array(out["queries"]).map { |q| q.to_s.downcase.strip }.reject(&:blank?).uniq.first(5)
    end
  end
end
