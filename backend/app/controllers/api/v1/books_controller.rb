module Api
  module V1
    class BooksController < BaseController
      DEFAULT_PER_PAGE = 25
      MAX_PER_PAGE = 100

      def index
        scope = Books::LibraryQuery.call(current_user.user_books, params.permit(:shelf, :tag, :rating, :year, :q, :sort))
        pagy = paginate(scope.count(:all))
        records = scope.offset(pagy.offset).limit(pagy.limit)

        render json: {
          data: UserBookSerializer.new(records).serializable_hash,
          meta: { page: pagy.page, per_page: pagy.limit, total: pagy.count, total_pages: pagy.pages }
        }
      end

      private

      # A page past the end is clamped to the last page instead of raising Pagy::OverflowError.
      def paginate(count)
        last = Pagy.new(count:, page: 1, limit: per_page_param).last
        Pagy.new(count:, page: page_param.clamp(1, last), limit: per_page_param)
      end

      def page_param = [ params[:page].to_i, 1 ].max

      def per_page_param
        value = params[:per_page].to_i
        value.positive? ? [ value, MAX_PER_PAGE ].min : DEFAULT_PER_PAGE
      end
    end
  end
end
