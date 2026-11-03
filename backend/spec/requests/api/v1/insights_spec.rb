require "rails_helper"

RSpec.describe "Insights", type: :request do
  let(:user) { create(:user) }

  describe "GET /api/v1/insights" do
    it "returns the stored snapshot" do
      create(:user_book, user:)
      ComputeInsightsJob.perform_now(user.id)

      get "/api/v1/insights", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      insights = response.parsed_body["insights"]
      expect(insights.keys).to match_array(%w[version computed_at coverage metrics])
      expect(insights["metrics"]["totals"]["read"]).to eq(1)
    end

    it "returns 204 when nothing is computed yet" do
      get "/api/v1/insights", headers: auth_headers(user)

      expect(response).to have_http_status(:no_content)
    end

    it "does not leak another user's insights" do
      create(:reading_insight, data: { "version" => 1 })

      get "/api/v1/insights", headers: auth_headers(user)

      expect(response).to have_http_status(:no_content)
    end

    it "requires auth" do
      get "/api/v1/insights"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/insights/refresh" do
    it "enqueues a recompute and returns 202" do
      expect { post "/api/v1/insights/refresh", headers: auth_headers(user) }
        .to have_enqueued_job(ComputeInsightsJob).with(user.id)

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body).to eq({})
    end

    it "requires auth" do
      post "/api/v1/insights/refresh"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
