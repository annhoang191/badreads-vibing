module Sessions
  # Verifies credentials and starts a session. Returns the Session.
  class Authenticate < ApplicationService
    def initialize(email_address:, password:, ip_address: nil, user_agent: nil)
      @email_address = email_address.to_s
      @password = password.to_s
      @session_attrs = { ip_address:, user_agent:, last_used_at: Time.current }
    end

    def call
      user = User.authenticate_by(email_address: @email_address, password: @password)
      raise ApiError::InvalidCredentials unless user

      user.sessions.create!(@session_attrs)
    end
  end
end
