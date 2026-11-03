module AuthHelpers
  def auth_headers(user, session: nil)
    session ||= create(:session, user:)
    { "Authorization" => "Bearer #{session.token}" }
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
