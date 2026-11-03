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

  class Conflict < ApiError
    def initialize(message = "Conflict", code: "conflict", **opts)
      super(message, code: code, status: :conflict, **opts)
    end
  end

  class InvalidFile < ApiError
    def initialize(message = "The uploaded file is not a valid CSV", **opts)
      super(message, code: "invalid_file", status: :unprocessable_content, **opts)
    end
  end

  class InvalidGoodreadsExport < ApiError
    def initialize(message = "The file is not a Goodreads export", **opts)
      super(message, code: "invalid_goodreads_export", status: :unprocessable_content, **opts)
    end
  end

  class ProfileNotPublic < ApiError
    def initialize(message = "This Goodreads profile was not found or is not public", **opts)
      super(message, code: "profile_not_public", status: :unprocessable_content, **opts)
    end
  end

  class NoGoodreadsProfile < ApiError
    def initialize(message = "Connect a Goodreads profile first", **opts)
      super(message, code: "no_goodreads_profile", status: :unprocessable_content, **opts)
    end
  end
end
