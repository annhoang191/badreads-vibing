module Recommendations
  # Fallback ranking when the agent fails or hits a guardrail (FR-C7): pre-score order with
  # author diversity and template reasons. Always produces something.
  class HeuristicRanker < ApplicationService
    def initialize(pool:, profile:)
      @pool = pool
      @profile = profile
    end

    def call
      per_author = Hash.new(0)
      @pool.top(@pool.size).each_with_object([]) do |c, picked|
        break picked if picked.size == Validator::COUNT
        next if per_author[c.author] >= Validator::MAX_PER_AUTHOR

        per_author[c.author] += 1
        picked << Validator::Ranked.new(candidate: c, score: (c.pre_score * 100).round.clamp(0, 100), reason: reason(c))
      end
    end

    private

    def reason(c)
      shared = c.subjects.select { |s| @profile.affinity_for(s).positive? }.max_by(2) { |s| @profile.affinity_for(s) }
      anchor = @profile.anchors.first&.dig(:title)
      text =
        if c.liked_author
          "You've rated #{c.author}'s books highly"
        elsif shared.any?
          "Shares #{shared.map { |s| "“#{s}”" }.join(' and ')} with books you rated highly"
        else
          "Popular with readers whose tastes overlap with yours"
        end
      text += ", like #{anchor}" if anchor && !c.liked_author
      "#{text}.".truncate(Validator::MAX_REASON)
    end
  end
end
