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
      super(message, code: "unprocessable", status: :unprocessable_entity, **opts)
    end
  end
end
