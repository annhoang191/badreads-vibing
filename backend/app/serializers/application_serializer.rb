# Base class for JSON serializers (Alba). Controllers render serializers,
# never models: `render json: ImportSerializer.new(import).serialize`.
class ApplicationSerializer
  include Alba::Resource
end
