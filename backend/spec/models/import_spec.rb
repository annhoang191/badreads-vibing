require "rails_helper"

RSpec.describe Import do
  it { is_expected.to belong_to(:user) }

  it do
    expect(build(:import)).to define_enum_for(:source).with_values(csv: "csv", rss: "rss")
                                                      .with_prefix.backed_by_column_of_type(:string).validating
  end

  it do
    expect(build(:import)).to define_enum_for(:status)
      .with_values(pending: "pending", processing: "processing", completed: "completed", failed: "failed")
      .with_prefix.backed_by_column_of_type(:string).validating
  end

  it "has an attached csv" do
    import = create(:import)
    import.csv.attach(io: StringIO.new("Book Id\n1"), filename: "x.csv", content_type: "text/csv")
    expect(import.csv).to be_attached
  end
end
