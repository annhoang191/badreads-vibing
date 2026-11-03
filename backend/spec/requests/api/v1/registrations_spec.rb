require "rails_helper"

RSpec.describe "POST /api/v1/registrations", type: :request do
  let(:params) { { email_address: "New@Example.com", password: "supersecret123" } }

  it "creates a user and returns a token" do
    post("/api/v1/registrations", params:)

    expect(response).to have_http_status(:created)
    body = response.parsed_body
    expect(body["token"].length).to eq(36)
    expect(body["user"]).to include("email_address" => "new@example.com")
    expect(body["user"].keys).to contain_exactly("id", "email_address", "created_at")
    expect(Session.find_by(token: body["token"]).user.email_address).to eq("new@example.com")
  end

  it "returns 422 for a short password" do
    post "/api/v1/registrations", params: params.merge(password: "short")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]["details"]).to have_key("password")
  end

  it "returns 422 for a duplicate email (case-insensitive)" do
    create(:user, email_address: "new@example.com")
    post("/api/v1/registrations", params:)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]["details"]).to have_key("email_address")
  end

  it "returns 422 when params are missing" do
    post "/api/v1/registrations", params: {}

    expect(response).to have_http_status(:unprocessable_content)
  end
end
