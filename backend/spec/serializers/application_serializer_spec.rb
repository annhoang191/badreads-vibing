require "rails_helper"

RSpec.describe ApplicationSerializer do
  it "serializes declared attributes only" do
    serializer = Class.new(described_class) { attributes :id, :title }
    book = Struct.new(:id, :title, :secret).new(1, "Dune", "hidden")

    expect(JSON.parse(serializer.new(book).serialize)).to eq("id" => 1, "title" => "Dune")
  end
end
