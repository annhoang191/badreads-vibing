module Subagents
  # simple tier (Haiku): reading profile -> compact persona for the ranker.
  class SummarizeReader < ApplicationService
    SCHEMA = {
      type: "object", additionalProperties: false, required: %w[persona likes dislikes],
      properties: { persona: { type: "string" },
                    likes: { type: "array", items: { type: "string" } },
                    dislikes: { type: "array", items: { type: "string" } } }
    }.freeze

    def initialize(llm:, profile:)
      @llm = llm
      @profile = profile
    end

    def call
      out = @llm.json(task: :summarize_reader, system: Llm::Prompt.for(:summarize_reader),
                      input: @profile.to_prompt, schema: SCHEMA, max_tokens: 1_000)
      { "persona" => out["persona"].to_s.truncate(600), "likes" => Array(out["likes"]).first(5),
        "dislikes" => Array(out["dislikes"]).first(5) }
    end
  end
end
