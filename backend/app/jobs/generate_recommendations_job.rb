class GenerateRecommendationsJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(batch_id)
    batch = RecommendationBatch.find(batch_id)
    return unless batch.status_pending? # idempotent: a retried job won't regenerate

    Recommendations::Pipeline.call(batch:)
  end
end
