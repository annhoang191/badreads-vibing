require "webmock/rspec"
require "vcr"

# Tests must never hit the network.
WebMock.disable_net_connect!(allow_localhost: true)

VCR.configure do |config|
  config.cassette_library_dir = Rails.root.join("spec/cassettes")
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data("<ANTHROPIC_API_KEY>") { Rails.application.credentials.dig(:anthropic, :api_key) }
end
