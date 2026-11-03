require "rails_helper"

RSpec.describe Recommendations::Validator do
  let(:pool) { pool_with(15) }

  it "returns ranked items for valid output" do
    ranked = described_class.call(output: ranking_for(pool), pool:)
    expect(ranked.size).to eq(10)
    expect(ranked.first).to have_attributes(score: 95, reason: /Ancillary Justice/)
  end

  it "rejects unknown ids (no invented books)" do
    out = ranking_for(pool)
    out["recommendations"][0]["id"] = "c999"
    expect { described_class.call(output: out, pool:) }.to raise_error(described_class::Invalid, /unknown id/)
  end

  it "rejects wrong counts, duplicates, bad scores and long reasons" do
    out = ranking_for(pool)
    out["recommendations"][1]["id"] = out["recommendations"][0]["id"]
    out["recommendations"][2]["score"] = 120
    out["recommendations"][3]["reason"] = "x" * 301
    out["recommendations"].pop
    expect { described_class.call(output: out, pool:) }.to raise_error(described_class::Invalid) { |e|
      expect(e.errors.join).to include("exactly 10", "duplicate", "score", "reason")
    }
  end

  it "rejects more than two books by one author" do
    pool = pool_with(15, authors: [ "Same", "A", "B", "C", "D" ])
    out = { "recommendations" => pool.top(15).select { |c| c.author == "Same" }.first(3)
      .concat(pool.top(15).reject { |c| c.author == "Same" }.first(7))
      .map { |c| { "id" => c.id, "score" => 80, "reason" => "fits" } } }
    expect { described_class.call(output: out, pool:) }.to raise_error(described_class::Invalid, /Same/)
  end
end
