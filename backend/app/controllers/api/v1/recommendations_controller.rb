module Api
  module V1
    class RecommendationsController < BaseController
      def index
        batch = batches.order(created_at: :desc, id: :desc).first
        render json: payload(batch)
      end

      def generate
        batch = create_batch
        GenerateRecommendationsJob.perform_later(batch.id)
        render json: payload(batch), status: :accepted
      end

      private

      def batches = current_user.recommendation_batches.includes(recommendations: :book)

      def payload(batch)
        {
          batch: batch && RecommendationBatchSerializer.new(batch).to_h,
          quota: Recommendations::Quota.new(user: current_user).to_h
        }
      end

      # Locking the user row serializes concurrent requests so the checks can't be raced.
      def create_batch
        current_user.with_lock do
          if current_user.recommendation_batches.where(status: %w[pending processing]).exists?
            raise ApiError::Conflict.new("Recommendations are already being generated", code: "batch_in_progress")
          end

          ensure_enough_data!
          ensure_quota!
          current_user.recommendation_batches.create!(status: :pending)
        end
      end

      def ensure_enough_data!
        have = current_user.user_books.shelf_read.where.not(my_rating: nil).count
        required = Recommendations::BuildProfile::MIN_RATED
        raise ApiError::NotEnoughData.new(details: { required:, have: }) if have < required
      end

      def ensure_quota!
        quota = Recommendations::Quota.new(user: current_user)
        return unless quota.exhausted?

        raise ApiError::RateLimited.new("Daily recommendation limit reached", details: { retry_after: quota.retry_after })
      end
    end
  end
end
