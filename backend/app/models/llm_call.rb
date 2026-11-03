class LlmCall < ApplicationRecord
  belongs_to :recommendation_batch, optional: true

  validates :task, :tier, :model, presence: true
end
