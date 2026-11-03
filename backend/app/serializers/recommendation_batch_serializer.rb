class RecommendationBatchSerializer < ApplicationSerializer
  attributes :id, :status, :ranked_by, :error_message, :created_at

  attribute :recommendations do |batch|
    next [] unless batch.status_completed?

    batch.recommendations.sort_by(&:position).map { |rec| RecommendationSerializer.new(rec).to_h }
  end
end
