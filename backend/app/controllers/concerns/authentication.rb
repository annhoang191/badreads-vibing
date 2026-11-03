# Bearer-token authentication (FR-A3, FR-A4). Every controller requires auth
# unless it calls `allow_unauthenticated_access`.
module Authentication
  extend ActiveSupport::Concern

  SESSION_TTL = 30.days
  TOUCH_INTERVAL = 1.minute

  included do
    before_action :require_authentication
    helper_method :current_user if respond_to?(:helper_method)
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def require_authentication
    session = find_session_by_token
    raise ApiError::Unauthorized unless session

    touch_session(session)
    Current.session = session
  end

  def find_session_by_token
    token = request.authorization.to_s[/\ABearer (\S+)\z/, 1]
    return if token.blank?

    session = Session.includes(:user).find_by(token: token)
    return unless session
    return session unless expired?(session)

    session.destroy
    nil
  end

  def expired?(session)
    (session.last_used_at || session.created_at) < SESSION_TTL.ago
  end

  def touch_session(session)
    return if session.last_used_at && session.last_used_at > TOUCH_INTERVAL.ago

    session.update_column(:last_used_at, Time.current)
  end

  def current_user = Current.user
end
