class ImportCsvJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(import_id) = Imports::ProcessCsv.call(import: Import.find(import_id))
end
