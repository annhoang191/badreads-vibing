module Recommendations
  # Normalized "title|author" identity used to match books across Goodreads and Open Library
  # when work keys are missing (FR-C5). Drops series suffixes like "(Mistborn, #1)".
  module BookKey
    module_function

    def for(title, author)
      t = title.to_s.downcase.sub(/\s*\(.*\)\s*\z/, "").sub(/:.*\z/, "").gsub(/[^a-z0-9]/, "")
      a = author.to_s.downcase.gsub(/[^a-z0-9]/, "")
      "#{t}|#{a}"
    end
  end
end
