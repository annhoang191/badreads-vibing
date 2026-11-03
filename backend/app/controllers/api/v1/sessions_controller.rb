module Api
  module V1
    class SessionsController < BaseController
      allow_unauthenticated_access only: :create
      rate_limit to: 10, within: 3.minutes, only: :create, with: -> { render_api_error(ApiError::RateLimited.new) }

      def create
        session = Sessions::Authenticate.call(
          email_address: params[:email_address], password: params[:password],
          ip_address: request.remote_ip, user_agent: request.user_agent
        )
        render json: { token: session.token, user: UserSerializer.new(session.user).to_h }, status: :created
      end

      def destroy
        Current.session.destroy
        head :no_content
      end
    end
  end
end
