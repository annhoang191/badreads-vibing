class RecommendationSerializer < ApplicationSerializer
  attributes :id, :position, :status, :reason

  attribute(:score) { |recommendation| recommendation.score.to_i }

  one :book, resource: RecommendedBookSerializer
end
