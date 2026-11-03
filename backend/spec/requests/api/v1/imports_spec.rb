require "rails_helper"

RSpec.describe "Imports API", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  def csv_upload(path_or_content, name: "export.csv", type: "text/csv")
    io = path_or_content.is_a?(Pathname) ? path_or_content.open : StringIO.new(path_or_content)
    Rack::Test::UploadedFile.new(io, type, original_filename: name)
  end

  describe "POST /api/v1/imports" do
    it "returns 401 without a token" do
      post "/api/v1/imports"
      expect(response).to have_http_status(:unauthorized)
    end

    it "creates a pending import, attaches the file and enqueues the job" do
      expect do
        post "/api/v1/imports", params: { file: csv_upload(file_fixture("goodreads_export.csv")) }, headers: headers
      end.to have_enqueued_job(ImportCsvJob)

      expect(response).to have_http_status(:accepted)
      body = response.parsed_body["import"]
      expect(body).to include("source" => "csv", "status" => "pending", "filename" => "export.csv", "stats" => {})
      expect(body.keys).to match_array(%w[id source status filename stats error_message started_at finished_at created_at])
      expect(Import.find(body["id"]).csv).to be_attached
    end

    it "returns 422 invalid_file for a non-csv file" do
      post "/api/v1/imports", params: { file: csv_upload("x", name: "a.txt", type: "text/plain") }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]["code"]).to eq("invalid_file")
    end

    it "returns 422 invalid_file when no file is sent" do
      post "/api/v1/imports", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]["code"]).to eq("invalid_file")
    end

    it "returns 422 invalid_goodreads_export naming the missing headers" do
      post "/api/v1/imports", params: { file: csv_upload(file_fixture("not_goodreads.csv")) }, headers: headers

      error = response.parsed_body["error"]
      expect(response).to have_http_status(:unprocessable_content)
      expect(error["code"]).to eq("invalid_goodreads_export")
      expect(error["message"]).to include("Book Id", "Exclusive Shelf")
    end

    it "returns 409 import_in_progress when one is pending or processing" do
      create(:import, user:, status: "processing")

      expect do
        post "/api/v1/imports", params: { file: csv_upload(file_fixture("goodreads_export.csv")) }, headers: headers
      end.not_to have_enqueued_job(ImportCsvJob)

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body["error"]["code"]).to eq("import_in_progress")
    end

    it "allows a new import after earlier ones finished or belong to someone else" do
      create(:import, :completed, user:)
      create(:import, user: create(:user))

      post "/api/v1/imports", params: { file: csv_upload(file_fixture("goodreads_export.csv")) }, headers: headers

      expect(response).to have_http_status(:accepted)
    end
  end

  describe "GET /api/v1/imports" do
    it "returns 401 without a token" do
      get "/api/v1/imports"
      expect(response).to have_http_status(:unauthorized)
    end

    it "lists the user's imports newest first, limited to 20" do
      create_list(:import, 21, :completed, user:).each_with_index { |i, n| i.update!(created_at: n.hours.ago) }
      create(:import)

      get "/api/v1/imports", headers: headers

      data = response.parsed_body["data"]
      expect(data.size).to eq(20)
      expect(data.map { |i| i["created_at"] }).to eq(data.map { |i| i["created_at"] }.sort.reverse)
    end
  end

  describe "GET /api/v1/imports/:id" do
    it "returns the import" do
      import = create(:import, :completed, user:, stats: { "rows_total" => 3 })

      get "/api/v1/imports/#{import.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["import"]).to include("id" => import.id, "status" => "completed", "stats" => { "rows_total" => 3 })
    end

    it "returns 404 for another user's import" do
      get "/api/v1/imports/#{create(:import).id}", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["error"]["code"]).to eq("not_found")
    end

    it "returns 401 without a token" do
      get "/api/v1/imports/1"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
