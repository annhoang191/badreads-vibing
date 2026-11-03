module Registrations
  # Creates a user and their first session. Returns the Session.
  class CreateUser < ApplicationService
    def initialize(email_address:, password:, ip_address: nil, user_agent: nil)
      @attrs = { email_address:, password: }
      @session_attrs = { ip_address:, user_agent:, last_used_at: Time.current }
    end

    def call
      ActiveRecord::Base.transaction do
        user = User.create!(@attrs)
        user.sessions.create!(@session_attrs)
      end
    end
  end
end
