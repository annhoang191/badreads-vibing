require "rails_helper"

RSpec.describe ApplicationQuery do
  let(:query) do
    Class.new(described_class) do
      def self.default_relation = [ 1, 2, 3, 4 ]
      def call = params[:min] ? relation.select { |n| n >= params[:min] } : relation
    end
  end

  it "uses the given relation and symbolizes params" do
    expect(query.call([ 5, 6, 7 ], { "min" => 6 })).to eq([ 6, 7 ])
  end

  it "falls back to the default relation" do
    expect(query.call(nil, min: 3)).to eq([ 3, 4 ])
  end

  it "accepts permitted controller params" do
    params = ActionController::Parameters.new(min: 4).permit(:min)
    expect(query.call(nil, params)).to eq([ 4 ])
  end

  it "requires a relation when no default is defined" do
    bare = Class.new(described_class) { def call = relation }
    expect { bare.call }.to raise_error(NotImplementedError)
  end
end
