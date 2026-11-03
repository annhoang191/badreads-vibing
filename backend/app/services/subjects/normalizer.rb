module Subjects
  # SPEC 4.2 steps 1-4: raw Open Library subjects -> clean, canonical, de-duplicated list.
  #
  #   Subjects::Normalizer.call(subjects: ["Science Fiction -- Fiction (Large type)", "nyt:hardcover"])
  #   # => ["science fiction"]
  #
  # Rules come from config/subject_denylist.yml and config/subject_aliases.yml (memoized), plus
  # `subject_mappings` rows, which win over the YAML (nil canonical_subject = discard). Read-only.
  class Normalizer < ApplicationService
    MAX_SUBJECTS = 15

    class << self
      def denylist
        @denylist ||= begin
          cfg = YAML.load_file(Rails.root.join("config/subject_denylist.yml"))
          {
            exact: Array(cfg["exact"]).to_set,
            patterns: Array(cfg["patterns"]).map { |src| Regexp.new(src, Regexp::IGNORECASE) }
          }
        end
      end

      def aliases
        @aliases ||= YAML.load_file(Rails.root.join("config/subject_aliases.yml")).transform_keys(&:to_s).freeze
      end

      def reset!
        @denylist = @aliases = nil
      end
    end

    def initialize(subjects:, mappings: nil)
      @subjects = Array(subjects)
      @mappings = mappings
    end

    def call
      result = []
      @subjects.each do |raw|
        split_parts(raw).each do |part|
          canonical = canonicalize(part)
          result << canonical if canonical
        end
      end
      result.uniq.first(MAX_SUBJECTS)
    end

    private

    # Step 1: lowercase/strip, split on " -- ", drop "(...)" text. Patterns such as
    # "(fictitious character)" are checked against the segment before the parentheses go.
    def split_parts(raw)
      raw.to_s.downcase.strip.split(" -- ").filter_map do |segment|
        next if denied?(segment.squish)

        segment.gsub(/\([^)]*\)/, "").squish.presence
      end
    end

    def canonicalize(part)
      return mappings[part] if mappings.key?(part)
      return if denied?(part)

      self.class.aliases.fetch(part, part)
    end

    def denied?(part)
      deny = self.class.denylist
      deny[:exact].include?(part) || deny[:patterns].any? { |re| re.match?(part) }
    end

    def mappings
      @mappings ||= SubjectMapping.pluck(:raw_subject, :canonical_subject).to_h
    end
  end
end
