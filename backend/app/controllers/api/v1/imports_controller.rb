module Api
  module V1
    class ImportsController < BaseController
      def index
        imports = current_user.imports.order(created_at: :desc, id: :desc).limit(20)
        render json: { data: ImportSerializer.new(imports).serializable_hash }
      end

      def show
        render json: { import: ImportSerializer.new(current_user.imports.find(params[:id])).to_h }
      end

      def create
        upload = Imports::CsvUpload.new(file: params[:file]).check!
        import = create_import(upload)
        ImportCsvJob.perform_later(import.id)
        render json: { import: ImportSerializer.new(import).to_h }, status: :accepted
      end

      private

      # Locking the user row serializes concurrent uploads so FR-I9 can't be raced.
      def create_import(upload)
        current_user.with_lock do
          if current_user.imports.where(status: %w[pending processing]).exists?
            raise ApiError::Conflict.new("An import is already in progress", code: "import_in_progress")
          end

          current_user.imports.create!(source: :csv, status: :pending, filename: upload.filename).tap do |import|
            import.csv.attach(upload.file)
          end
        end
      end
    end
  end
end
