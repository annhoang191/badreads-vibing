require "rails_helper"

RSpec.describe "/api/v1/session", type: :request do
  let!(:user) { create(:user, email_address: "reader@example.com", password: "supersecret123") }

  describe "POST" do
    it "logs in with valid credentials" do
      post "/api/v1/session", params: { email_address: "READER@example.com", password: "supersecret123" }

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["token"].length).to eq(36)
      expect(body["user"]["id"]).to eq(user.id)
    end

    it "returns 401 invalid_credentials for a wrong password" do
      post "/api/v1/session", params: { email_address: "reader@example.com", password: "wrong-password" }

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["error"]["code"]).to eq("invalid_credentials")
    end

    it "returns 401 for an unknown email" do
      post "/api/v1/session", params: { email_address: "nobody@example.com", password: "supersecret123" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "rate limits after 10 attempts" do
      11.times { post "/api/v1/session", params: { email_address: "reader@example.com", password: "bad" } }

      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body["error"]["code"]).to eq("rate_limited")
    end
  end

  describe "DELETE" do
    it "destroys only the current session" do
      other = create(:session, user:)
      current = create(:session, user:)

      delete "/api/v1/session", headers: { "Authorization" => "Bearer #{current.token}" }

      expect(response).to have_http_status(:no_content)
      expect(Session.exists?(current.id)).to be(false)
      expect(Session.exists?(other.id)).to be(true)
    end

    it "requires authentication" do
      delete "/api/v1/session"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
