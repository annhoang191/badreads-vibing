require "rails_helper"

RSpec.describe ApplicationService do
  it "builds the service with the given arguments and calls it" do
    service = Class.new(described_class) do
      def initialize(a, b:) = (@a, @b = a, b)
      def call = @a + @b
    end

    expect(service.call(1, b: 2)).to eq(3)
  end

  it "requires subclasses to implement #call" do
    expect { Class.new(described_class).call }.to raise_error(NotImplementedError)
  end
end
