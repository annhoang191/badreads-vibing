module Api
  module V1
    class GoodreadsProfilesController < BaseController
      # One manual sync per 10 minutes per user (FR-R3).
      rate_limit to: 1, within: 10.minutes, only: :sync, by: -> { Current.user.id },
                 with: -> { render_api_error(ApiError::RateLimited.new) }

      def show
        profile = current_user.goodreads_profile
        return head :no_content unless profile

        render json: { profile: serialize(profile) }
      end

      def update
        user_id = Goodreads::UserIdParser.call(params.require(:goodreads_user_id))
        validate_public!(user_id)
        profile = current_user.goodreads_profile || current_user.build_goodreads_profile
        profile.goodreads_user_id = user_id
        profile.rss_enabled = ActiveModel::Type::Boolean.new.cast(params.fetch(:rss_enabled, profile.rss_enabled))
        profile.consecutive_failures = 0 if profile.rss_enabled_changed? || profile.goodreads_user_id_changed?
        profile.save!
        render json: { profile: serialize(profile) }
      end

      def sync
        profile = current_user.goodreads_profile or raise ApiError::NoGoodreadsProfile
        import = Goodreads::SyncProfile.start_import!(profile)
        SyncRssJob.perform_later(profile.id, import.id)
        render json: { import: ImportSerializer.new(import).to_h }, status: :accepted
      end

      private

      def serialize(profile) = GoodreadsProfileSerializer.new(profile).to_h

      def validate_public!(user_id)
        Goodreads::RssClient.new.fetch_page(user_id:, shelf: "read", page: 1)
      rescue Goodreads::RssClient::ProfileNotPublic
        raise ApiError::ProfileNotPublic
      end
    end
  end
end
