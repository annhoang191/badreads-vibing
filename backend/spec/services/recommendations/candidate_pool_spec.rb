require "rails_helper"

RSpec.describe Recommendations::CandidatePool do
  it "issues opaque ids and dedupes by work key" do
    pool = described_class.new(profile: rec_profile)
    pool.add(raw_candidates(3))
    pool.add(raw_candidates(3))
    expect(pool.size).to eq(3)
    expect(pool.top(3).map(&:id)).to all(match(/\Ac\d+\z/))
  end

  it "excludes shelved/dismissed books by work key and by title+author" do
    profile = rec_profile(excluded_work_keys: Set["/works/OL1W"],
                          excluded_book_keys: Set[Recommendations::BookKey.for("Book 2 (Series, #1)", "Author 2")])
    pool = described_class.new(profile:)
    pool.add(raw_candidates(3))
    expect(pool.top(10).map(&:title)).to eq([ "Book 3" ])
  end

  it "drops candidates missing title, author or cover" do
    pool = described_class.new(profile: rec_profile)
    pool.add([ raw_candidates(1).first.merge(cover_id: nil), raw_candidates(2).last.merge(author: "") ])
    expect(pool.size).to eq(0)
  end

  it "ranks liked authors and matching subjects above others" do
    pool = described_class.new(profile: rec_profile)
    pool.add([
      raw_candidates(1).first.merge(work_key: "/works/A", author: "Someone", raw_subjects: [ "Cooking" ]),
      raw_candidates(1).first.merge(work_key: "/works/B", author: "Someone Else", raw_subjects: [ "Science fiction" ]),
      raw_candidates(1).first.merge(work_key: "/works/C", author: "Ann Leckie", raw_subjects: [ "Science fiction" ])
    ])
    expect(pool.top(3).map(&:work_key)).to eq(%w[/works/C /works/B /works/A])
  end
end
