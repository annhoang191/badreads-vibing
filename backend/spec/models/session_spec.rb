require "rails_helper"

RSpec.describe Session do
  it { is_expected.to belong_to(:user) }

  it "generates a 36 character token" do
    expect(create(:session).token.length).to eq(36)
  end
end
