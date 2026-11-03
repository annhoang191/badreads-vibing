require "csv"

module Goodreads
  # Thin wrapper over Ruby's CSV that tolerates a UTF-8 BOM and CRLF line endings.
  # Raises CSV::MalformedCSVError for files that aren't valid CSV (a file-level
  # failure, see FR-I6).
  module CsvReader
    BOM = "﻿".freeze

    module_function

    # Returns an Enumerator of field arrays (header row included).
    def records(text)
      text = text.to_s.dup.force_encoding(Encoding::UTF_8)
      text.delete_prefix!(BOM)
      CSV.new(text, nil_value: "", empty_value: "").each
    end
  end
end
