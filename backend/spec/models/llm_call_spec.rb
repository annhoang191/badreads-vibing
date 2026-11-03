require "rails_helper"

RSpec.describe LlmCall do
  it { is_expected.to belong_to(:recommendation_batch).optional }
  it { is_expected.to validate_presence_of(:task) }
  it { is_expected.to validate_presence_of(:tier) }
  it { is_expected.to validate_presence_of(:model) }
end
