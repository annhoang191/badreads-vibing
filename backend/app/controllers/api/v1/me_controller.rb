module Api
  module V1
    class MeController < BaseController
      def show
        render json: {
          user: UserSerializer.new(current_user).to_h,
          stats: {
            books: current_user.user_books.count,
            last_import_at: current_user.imports.status_completed.maximum(:finished_at)
          }
        }
      end
    end
  end
end
