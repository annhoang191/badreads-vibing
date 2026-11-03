module Api
  module V1
    class BaseController < ApplicationController
      rescue_from ApiError, with: :render_api_error
      rescue_from ActiveRecord::RecordNotFound do |e|
        render_api_error(ApiError::NotFound.new(e.message))
      end
      rescue_from ActiveRecord::RecordInvalid do |e|
        render_api_error(ApiError::Unprocessable.new(details: e.record.errors.to_hash))
      end
      rescue_from ActiveModel::ValidationError do |e|
        render_api_error(ApiError::Unprocessable.new(details: e.model.errors.to_hash))
      end
      rescue_from ActionController::ParameterMissing do |e|
        render_api_error(ApiError::Unprocessable.new(e.message))
      end

      private

      def render_api_error(error)
        render json: { error: { code: error.code, message: error.message, details: error.details } },
               status: error.status
      end
    end
  end
end
