module Goodreads
  # Accepts a bare numeric id or a profile URL (".../user/show/123-name") and returns the digits.
  class UserIdParser < ApplicationService
    def initialize(input) = @input = input.to_s.strip

    def call
      digits = @input[/\A\d+\z/] || @input[%r{/user/show/(\d+)}, 1]
      digits or raise ApiError::Unprocessable.new("Enter a Goodreads user ID or profile URL",
                                                  details: { goodreads_user_id: [ "is invalid" ] })
    end
  end
end
