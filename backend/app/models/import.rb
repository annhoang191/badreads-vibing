class Import < ApplicationRecord
  belongs_to :user
  has_one_attached :csv

  enum :source, { csv: "csv", rss: "rss" }, prefix: true, validate: true
  enum :status, { pending: "pending", processing: "processing", completed: "completed", failed: "failed" },
       prefix: true, validate: true
end
