class ImportSerializer < ApplicationSerializer
  attributes :id, :source, :status, :filename, :stats, :error_message, :started_at, :finished_at, :created_at
end
