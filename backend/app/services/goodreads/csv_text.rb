module Goodreads
  # Normalizes text from CSV files that may have been re-saved by a spreadsheet app:
  # zero-width characters, non-breaking spaces, doubled spaces and header case all vary
  # in the wild. Ruby's String#strip only removes ASCII whitespace, so it isn't enough.
  module CsvText
    INVISIBLE = /[​-‍⁠﻿]/
    EDGE_SPACE = /\A[[:space:]]+|[[:space:]]+\z/

    module_function

    # Single-line field: drop invisibles, collapse any Unicode whitespace, trim.
    def clean(value) = value.to_s.gsub(INVISIBLE, "").gsub(/[[:space:]]+/, " ").strip

    # Multi-line text (reviews): drop invisibles and trim edges, keep inner line breaks.
    def trim(value) = value.to_s.gsub(INVISIBLE, "").gsub(EDGE_SPACE, "")

    # Lookup key for a header: "My Rating " and "my rating" both -> "my rating".
    def header_key(name) = clean(name).downcase
  end
end
