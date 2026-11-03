class ComputeInsightsJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(user_id)
    user = User.find(user_id)
    data = Analytics::ReadingProfile.call(user:)
    insight = ReadingInsight.find_or_initialize_by(user_id: user.id)
    insight.update!(version: data[:version], data:, computed_at: data[:computed_at])
  end
end
