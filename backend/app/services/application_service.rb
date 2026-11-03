# Base class for service objects: one business operation, one public method.
#
#   class Imports::Upserter < ApplicationService
#     def initialize(user:, rows:) = (@user, @rows = user, rows)
#     def call = ...
#   end
#
#   Imports::Upserter.call(user:, rows:)
#
# Expected failures raise ApiError subclasses (see app/errors/api_error.rb);
# Api::V1::BaseController renders them. Don't return Result objects.
class ApplicationService
  def self.call(...) = new(...).call

  def call
    raise NotImplementedError, "#{self.class.name} must implement #call"
  end
end
