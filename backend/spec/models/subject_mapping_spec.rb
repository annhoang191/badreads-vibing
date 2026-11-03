require "rails_helper"

RSpec.describe SubjectMapping do
  subject { build(:subject_mapping) }

  it { is_expected.to validate_presence_of(:raw_subject) }
  it { is_expected.to validate_uniqueness_of(:raw_subject) }
  it { is_expected.to define_enum_for(:source).with_values(config: "config", llm: "llm").with_prefix.backed_by_column_of_type(:string).validating }

  it "allows a nil canonical subject (discard)" do
    expect(build(:subject_mapping, canonical_subject: nil)).to be_valid
  end
end
