class SubjectMapping < ApplicationRecord
  enum :source, { config: "config", llm: "llm" }, prefix: true, validate: true

  validates :raw_subject, presence: true, uniqueness: true
end
