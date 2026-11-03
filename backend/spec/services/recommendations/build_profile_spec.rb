require "rails_helper"

RSpec.describe Recommendations::BuildProfile do
  let(:user) { create(:user) }

  it "summarizes ratings, anchors, liked authors and exclusions" do
    loved = create(:book, title: "Dune", author: "Frank Herbert", open_library_work_key: "/works/OL1W")
    create(:user_book, user:, book: loved, my_rating: 5, date_read: Date.new(2026, 1, 1))
    create(:user_book, user:, book: create(:book, author: "Frank Herbert"), my_rating: 5)
    create(:user_book, user:, book: create(:book, title: "Meh", author: "X"), my_rating: 1)
    tbr = create(:book, title: "Later (Series, #2)", author: "Y")
    create(:user_book, user:, book: tbr, exclusive_shelf: "to-read", my_rating: nil, date_read: nil)

    profile = described_class.call(user:)

    expect(profile).to have_attributes(rated_read_count: 3, total_read: 3, top_authors: [ "Frank Herbert" ])
    expect(profile.anchors.map { |a| a[:title] }).to include("Dune")
    expect(profile.anti_anchors).to eq([ { title: "Meh", author: "X", rating: 1 } ])
    expect(profile.excluded_work_keys).to include("/works/OL1W")
    expect(profile.excluded_book_keys).to include(Recommendations::BookKey.for("Later", "Y"))
  end
end
