require "rails_helper"

RSpec.describe Subjects::Normalizer do
  def normalize(*subjects, **opts) = described_class.call(subjects:, **opts)

  it "lowercases and strips" do
    expect(normalize("  Space Opera  ")).to eq([ "space opera" ])
  end

  it "drops exact denylist entries" do
    expect(normalize("Fiction", "Accessible book", "Protected DAISY", "In library", "Large type books",
                     "Lending library", "English language", "New York Times bestseller", "Dystopia"))
      .to eq([ "dystopia" ])
  end

  it "drops denylist patterns" do
    expect(normalize("nyt:hardcover-fiction=2020", "1984", "Translations from French", "Dragons")).to eq([ "dragons" ])
  end

  it "drops text in parentheses" do
    expect(normalize("Dragons (Fantasy)", "Wizards (Magic)")).to eq([ "dragons", "magic" ])
  end

  it "drops subjects whose parenthetical matches a pattern" do
    expect(normalize("Holmes, Sherlock (Fictitious character)")).to eq([])
  end

  it "splits on ' -- ' and filters each part" do
    expect(normalize("Fiction -- Science Fiction -- Time travel")).to eq([ "science fiction", "time travel" ])
  end

  it "maps aliases" do
    expect(normalize("Sci-Fi", "Epic fantasy", "Memoirs")).to eq([ "science fiction", "fantasy", "memoir" ])
  end

  it "de-duplicates after aliasing" do
    expect(normalize("sci-fi", "Science Fiction", "science-fiction")).to eq([ "science fiction" ])
  end

  it "keeps at most 15" do
    expect(normalize(*(1..30).map { |i| "topic #{i}" }).size).to eq(15)
  end

  it "lets subject_mappings override config, with nil discarding" do
    create(:subject_mapping, raw_subject: "dragons", canonical_subject: "fantasy creatures")
    create(:subject_mapping, raw_subject: "noise", canonical_subject: nil)

    expect(normalize("Dragons", "Noise", "Elves")).to eq([ "fantasy creatures", "elves" ])
  end

  it "accepts nil" do
    expect(normalize(nil)).to eq([])
  end
end
