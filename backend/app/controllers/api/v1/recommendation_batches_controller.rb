module Api
  module V1
    class RecommendationBatchesController < BaseController
      def show
        batch = current_user.recommendation_batches.includes(recommendations: :book).find(params[:id])
        render json: { batch: RecommendationBatchSerializer.new(batch).to_h }
      end
    end
  end
end
