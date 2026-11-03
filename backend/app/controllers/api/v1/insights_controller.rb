module Api
  module V1
    class InsightsController < BaseController
      def show
        insight = current_user.reading_insight
        return head :no_content unless insight

        render json: { insights: insight.data }
      end

      def refresh
        ComputeInsightsJob.perform_later(current_user.id)
        render json: {}, status: :accepted
      end
    end
  end
end
