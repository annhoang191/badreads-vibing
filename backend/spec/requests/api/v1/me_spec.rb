require "rails_helper"

RSpec.describe "GET /api/v1/me", type: :request do
  let(:user) { create(:user) }

  it "returns the user and stats" do
    create_list(:user_book, 2, user:)
    create(:import, :completed, user:, finished_at: Time.utc(2026, 11, 3, 10))
    create(:import, user:)

    get "/api/v1/me", headers: auth_headers(user)

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["user"]["email_address"]).to eq(user.email_address)
    expect(body["stats"]).to eq("books" => 2, "last_import_at" => "2026-11-03T10:00:00.000Z")
  end

  it "returns null last_import_at without imports" do
    get "/api/v1/me", headers: auth_headers(user)

    expect(response.parsed_body["stats"]).to eq("books" => 0, "last_import_at" => nil)
  end

  it "returns 401 without a token" do
    get "/api/v1/me"

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body["error"]["code"]).to eq("unauthorized")
  end

  it "returns 401 for an invalid token" do
    get "/api/v1/me", headers: { "Authorization" => "Bearer nope" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 401 for a malformed header" do
    get "/api/v1/me", headers: { "Authorization" => "Token abc" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects sessions idle for more than 30 days" do
    session = create(:session, user:, last_used_at: 31.days.ago)

    get "/api/v1/me", headers: { "Authorization" => "Bearer #{session.token}" }

    expect(response).to have_http_status(:unauthorized)
    expect(Session.exists?(session.id)).to be(false)
  end

  it "touches last_used_at at most once per minute" do
    session = create(:session, user:, last_used_at: 2.minutes.ago)
    headers = { "Authorization" => "Bearer #{session.token}" }

    get("/api/v1/me", headers:)
    first = session.reload.last_used_at
    expect(first).to be > 1.minute.ago

    get("/api/v1/me", headers:)
    expect(session.reload.last_used_at).to eq(first)
  end
end
