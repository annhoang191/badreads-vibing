module Recommendations
  # Generates one recommendation batch end to end (SPEC §4.3):
  # profile -> initial candidates -> orchestrator agent -> (heuristic fallback) -> persist.
  # Never raises for model problems; the batch ends completed (agent or heuristic) or failed.
  class Pipeline < ApplicationService
    INITIAL_AUTHORS = 5
    INITIAL_SUBJECTS = 8

    def initialize(batch:, source: CandidateSource.new, llm: nil, orchestrator: RecommendationOrchestrator)
      @batch = batch
      @source = source
      @llm = llm || Llm::Client.new(batch:)
      @orchestrator = orchestrator
    end

    def call
      @batch.update!(status: :processing, prompt_version: Llm::Router.prompt_version)
      profile = BuildProfile.call(user: @batch.user)
      pool = CandidatePool.new(profile:)
      pool.add(@source.fetch(subjects: profile.top_subjects.first(INITIAL_SUBJECTS).map { |s| s[:subject] },
                             authors: profile.top_authors.first(INITIAL_AUTHORS)))
      raise NoCandidates if pool.size < Validator::COUNT

      ranked, ranked_by, turns = rank(profile, pool)
      persist!(ranked, ranked_by:, turns:)
    rescue NoCandidates
      fail!("We couldn't find enough new books to suggest right now. Please try again later.")
    rescue StandardError => e
      Rails.error.report(e, context: { recommendation_batch_id: @batch.id })
      fail!("Something went wrong while generating recommendations.")
    end

    class NoCandidates < StandardError; end

    private

    def rank(profile, pool)
      result = @orchestrator.call(llm: @llm, profile:, pool:, source: @source)
      [ result.ranked, :agent, result.turns ]
    rescue RecommendationOrchestrator::Failed => e
      Rails.logger.warn("[recommendations] batch #{@batch.id} falling back to heuristic: #{e.message}")
      ranked = HeuristicRanker.call(pool:, profile:)
      raise NoCandidates if ranked.size < Validator::COUNT

      [ ranked, :heuristic, nil ]
    end

    def persist!(ranked, ranked_by:, turns:)
      ActiveRecord::Base.transaction do
        ranked.each_with_index do |r, i|
          @batch.recommendations.create!(user: @batch.user, book: book_for(r.candidate),
                                         position: i + 1, score: r.score, reason: r.reason)
        end
        @batch.update!(status: :completed, ranked_by:, agent_turns: turns, **costs)
      end
    end

    def book_for(c)
      Book.find_or_create_by!(open_library_work_key: c.work_key) do |b|
        b.assign_attributes(source: :open_library, title: c.title, author: c.author, cover_url: c.cover_url,
                            original_publication_year: c.year, num_pages: c.pages, subjects: c.subjects,
                            enrichment_status: :enriched, enriched_at: Time.current)
      end
    end

    def costs
      by_tier = @batch.llm_calls.group(:tier).sum(:cost_usd).transform_values { |v| v.to_f.round(6) }
      { total_cost_usd: by_tier.values.sum, cost_by_tier: by_tier }
    end

    def fail!(message)
      @batch.update!(status: :failed, error_message: message, **costs)
    end
  end
end
