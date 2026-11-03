require "rails_helper"

RSpec.describe ImportCsvJob do
  it "delegates to Imports::ProcessCsv" do
    import = create(:import)
    allow(Imports::ProcessCsv).to receive(:call)

    described_class.perform_now(import.id)

    expect(Imports::ProcessCsv).to have_received(:call).with(import:)
  end

  it "discards when the import no longer exists" do
    expect { described_class.perform_now(0) }.not_to raise_error
  end
end
