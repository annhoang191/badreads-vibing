# Base class for query objects: complex reads that return a relation.
#
#   class Books::LibraryQuery < ApplicationQuery
#     def self.default_relation = UserBook.none
#     def call
#       scope = relation
#       scope = scope.where(exclusive_shelf: params[:shelf]) if params[:shelf].present?
#       scope
#     end
#   end
#
#   Books::LibraryQuery.call(current_user.user_books, permitted_params)
#
# Always return a relation (chainable, paginatable). Never load records here.
class ApplicationQuery
  def self.call(relation = nil, params = {})
    new(relation || default_relation, params).call
  end

  def self.default_relation
    raise NotImplementedError, "#{name} must define .default_relation or be given a relation"
  end

  attr_reader :relation, :params

  def initialize(relation, params = {})
    @relation = relation
    @params = params.to_h.symbolize_keys
  end

  def call
    raise NotImplementedError, "#{self.class.name} must implement #call"
  end
end
