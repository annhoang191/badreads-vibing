require "rails_helper"

RSpec.describe "Goodreads profile API", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:feed) { "https://www.goodreads.com/review/list_rss/4567" }
  let(:page1) { file_fixture("goodreads_rss_read_page1.xml").read }

  def stub_validation(status: 200, body: page1)
    stub_request(:get, feed).with(query: { shelf: "read", page: 1 }).to_return(status:, body:)
  end

  describe "auth" do
    it "returns 401 without a token" do
      get "/api/v1/goodreads_profile"
      expect(response).to have_http_status(:unauthorized)
      post "/api/v1/goodreads_profile/sync"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/goodreads_profile" do
    it "returns 204 when none" do
      get "/api/v1/goodreads_profile", headers: headers
      expect(response).to have_http_status(:no_content)
    end

    it "returns the profile" do
      create(:goodreads_profile, user:, goodreads_user_id: "42", rss_enabled: true, last_error: "x")
      get "/api/v1/goodreads_profile", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["profile"]).to eq(
        "goodreads_user_id" => "42", "rss_enabled" => true, "last_synced_at" => nil,
        "last_error" => "x", "consecutive_failures" => 0
      )
    end
  end

  describe "PUT /api/v1/goodreads_profile" do
    it "creates a profile from digits" do
      stub_validation
      put "/api/v1/goodreads_profile", params: { goodreads_user_id: "4567", rss_enabled: true }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["profile"]).to include("goodreads_user_id" => "4567", "rss_enabled" => true)
      expect(user.reload.goodreads_profile).to be_present
    end

    it "extracts the id from a profile URL and updates an existing profile" do
      create(:goodreads_profile, user:, goodreads_user_id: "1", consecutive_failures: 3, rss_enabled: false)
      stub_validation
      put "/api/v1/goodreads_profile",
          params: { goodreads_user_id: "https://www.goodreads.com/user/show/4567-jane-doe", rss_enabled: true },
          headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(GoodreadsProfile.count).to eq(1)
      expect(user.goodreads_profile.reload).to have_attributes(goodreads_user_id: "4567", consecutive_failures: 0,
                                                                rss_enabled: true)
    end

    it "returns 422 profile_not_public" do
      stub_validation(status: 404, body: "nope")
      put "/api/v1/goodreads_profile", params: { goodreads_user_id: "4567" }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("profile_not_public")
      expect(GoodreadsProfile.count).to eq(0)
    end

    it "returns 422 for an unparsable id" do
      put "/api/v1/goodreads_profile", params: { goodreads_user_id: "jane" }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("unprocessable")
    end
  end

  describe "POST /api/v1/goodreads_profile/sync" do
    it "returns 422 without a profile" do
      post "/api/v1/goodreads_profile/sync", headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    context "with a profile" do
      before { create(:goodreads_profile, user:) }

      it "creates a pending import and enqueues the job" do
        expect { post "/api/v1/goodreads_profile/sync", headers: headers }.to have_enqueued_job(SyncRssJob)

        expect(response).to have_http_status(:accepted)
        expect(response.parsed_body["import"]).to include("source" => "rss", "status" => "pending")
      end

      it "returns 409 when an import is in progress" do
        create(:import, user:, status: "processing")
        post "/api/v1/goodreads_profile/sync", headers: headers

        expect(response).to have_http_status(:conflict)
        expect(response.parsed_body.dig("error", "code")).to eq("import_in_progress")
      end

      it "returns 429 on a second sync within 10 minutes" do
        post "/api/v1/goodreads_profile/sync", headers: headers
        post "/api/v1/goodreads_profile/sync", headers: headers

        expect(response).to have_http_status(:too_many_requests)
        expect(response.parsed_body.dig("error", "code")).to eq("rate_limited")
      end
    end
  end
end
