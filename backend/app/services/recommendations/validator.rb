module Recommendations
  # Validates ranked output against the pool (SPEC §4.3 step 4). Never trust the model:
  # every id must be one the pool issued.
  class Validator < ApplicationService
    COUNT = 10
    MAX_REASON = 300
    MAX_PER_AUTHOR = 2

    Ranked = Data.define(:candidate, :score, :reason)

    class Invalid < StandardError
      attr_reader :errors

      def initialize(errors)
        @errors = errors
        super(errors.join("; "))
      end
    end

    def initialize(output:, pool:)
      @items = Array(output.is_a?(Hash) ? (output["recommendations"] || output[:recommendations]) : nil)
      @pool = pool
    end

    def call
      errors = []
      errors << "expected exactly #{COUNT} recommendations, got #{@items.size}" unless @items.size == COUNT

      ranked = @items.each_with_index.filter_map do |item, i|
        item = item.to_h.stringify_keys
        candidate = @pool.find(item["id"].to_s)
        score = item["score"]
        reason = item["reason"].to_s.strip
        errors << "item #{i + 1}: unknown id #{item['id'].inspect}" and next unless candidate
        errors << "item #{i + 1}: score must be an integer 0-100" unless score.is_a?(Integer) && score.between?(0, 100)
        errors << "item #{i + 1}: reason must be 1-#{MAX_REASON} characters" unless reason.length.between?(1, MAX_REASON)
        Ranked.new(candidate:, score:, reason:)
      end

      ids = ranked.map { |r| r.candidate.id }
      errors << "duplicate ids: #{ids.tally.select { |_, n| n > 1 }.keys.join(', ')}" if ids.uniq.size != ids.size
      ranked.group_by { |r| r.candidate.author }.each do |author, rs|
        errors << "more than #{MAX_PER_AUTHOR} books by #{author}" if rs.size > MAX_PER_AUTHOR
      end

      raise Invalid, errors if errors.any?

      ranked
    end
  end
end
