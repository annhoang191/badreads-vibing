# Base class for errors rendered as `{ error: { code:, message:, details: } }`.
class ApiError < StandardError
  attr_reader :code, :status, :details

  def initialize(message = nil, code: "internal_error", status: :internal_server_error, details: {})
    super(message || code.humanize)
    @code = code
    @status = status
    @details = details
  end

  class NotFound < ApiError
    def initialize(message = "Resource not found", **opts)
      super(message, code: "not_found", status: :not_found, **opts)
    end
  end

  class Unauthorized < ApiError
    def initialize(message = "Authentication required", **opts)
      super(message, code: "unauthorized", status: :unauthorized, **opts)
    end
  end

  class Unprocessable < ApiError
    def initialize(message = "Validation failed", **opts)
      super(message, code: "unprocessable", status: :unprocessable_content, **opts)
    end
  end

  class InvalidCredentials < ApiError
    def initialize(message = "Invalid email address or password", **opts)
      super(message, code: "invalid_credentials", status: :unauthorized, **opts)
    end
  end

  class RateLimited < ApiError
    def initialize(message = "Too many requests, try again later", **opts)
      super(message, code: "rate_limited", status: :too_many_requests, **opts)
    end
  end
end
