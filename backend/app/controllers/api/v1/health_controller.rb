module Api
  module V1
    class HealthController < BaseController
      allow_unauthenticated_access

      def show
        render json: { status: "ok", time: Time.current.iso8601 }
      end
    end
  end
end
