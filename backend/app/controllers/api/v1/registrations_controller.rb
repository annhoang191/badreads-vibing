module Api
  module V1
    class RegistrationsController < BaseController
      allow_unauthenticated_access only: :create

      def create
        session = Registrations::CreateUser.call(**registration_params, ip_address: request.remote_ip,
                                                                        user_agent: request.user_agent)
        render json: { token: session.token, user: UserSerializer.new(session.user).to_h }, status: :created
      end

      private

      def registration_params
        params.expect(:email_address, :password).then { |e, p| { email_address: e, password: p } }
      end
    end
  end
end
