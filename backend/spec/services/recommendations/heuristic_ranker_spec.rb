require "rails_helper"

RSpec.describe Recommendations::HeuristicRanker do
  it "picks 10 diverse candidates with template reasons" do
    pool = pool_with(20, authors: [ "Ann Leckie", "B", "C", "D", "E" ])
    ranked = described_class.call(pool:, profile: rec_profile)

    expect(ranked.size).to eq(10)
    expect(ranked.map { |r| r.candidate.author }.tally.values.max).to be <= 2
    expect(ranked).to all(have_attributes(reason: a_string_matching(/\S/)))
    expect(ranked.find { |r| r.candidate.author == "Ann Leckie" }.reason).to include("Ann Leckie")
    expect(Recommendations::Validator.call(
      output: { "recommendations" => ranked.map { |r| { "id" => r.candidate.id, "score" => r.score, "reason" => r.reason } } },
      pool:
    ).size).to eq(10)
  end
end
