require "rails_helper"

RSpec.describe ApiError do
  it "carries code, status and details" do
    error = ApiError::Unprocessable.new(details: { email: [ "is invalid" ] })

    expect(error.code).to eq("unprocessable")
    expect(error.status).to eq(:unprocessable_entity)
    expect(error.details).to eq(email: [ "is invalid" ])
  end
end
