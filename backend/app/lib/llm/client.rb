module Llm
  # The only place that talks to the Claude API. Resolves model/effort from Llm::Router,
  # enables server-side fallbacks where the tier allows, logs every call to llm_calls,
  # and turns refusals / truncation / API failures into Llm::Client::Error subclasses.
  class Client
    class Error < StandardError; end
    class Refused < Error; end
    class Truncated < Error; end
    class InvalidJson < Error; end

    FALLBACK_BETA = "server-side-fallback-2026-07-01".freeze

    def initialize(batch: nil, anthropic: nil)
      @batch = batch
      @anthropic = anthropic
    end

    # Raw Messages API call. Returns the SDK response (stop_reason may be :tool_use or :end_turn).
    def create(task:, system:, messages:, max_tokens:, tools: nil, schema: nil)
      tier = Router.for(task)
      params = build_params(tier, system:, messages:, max_tokens:, tools:, schema:)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      response = anthropic.beta.messages.create(**params)
      record(task, tier, response:, started:)
      check_stop!(response)
      response
    rescue Anthropic::Errors::Error => e
      record(task, tier, started:, error: e) if tier
      raise Error, "#{task}: #{e.class.name.demodulize}: #{e.message}"
    end

    # Single structured-output call: sends `input` as JSON, returns the parsed JSON object.
    def json(task:, system:, input:, schema:, max_tokens: 2_000)
      response = create(task:, system:, max_tokens:, schema:,
                        messages: [ { role: "user", content: JSON.generate(input) } ])
      JSON.parse(self.class.text_of(response))
    rescue JSON::ParserError => e
      raise InvalidJson, "#{task}: #{e.message}"
    end

    def self.text_of(response)
      response.content.select { |b| b.type == :text }.map(&:text).join
    end

    private

    def anthropic
      @anthropic ||= begin
        key = Rails.application.credentials.dig(:anthropic, :api_key) || ENV.fetch("ANTHROPIC_API_KEY", nil)
        # Fail fast (-> heuristic fallback) instead of making a doomed 401 round trip.
        raise Error, "Anthropic API key is not configured" if key.blank?

        Anthropic::Client.new(api_key: key)
      end
    end

    def build_params(tier, system:, messages:, max_tokens:, tools:, schema:)
      output_config = { effort: tier.effort.to_sym }
      output_config[:format_] = { type: :json_schema, schema: } if schema

      params = {
        model: tier.model.to_sym,
        max_tokens:,
        # Static per task, so it's cacheable; per-user data only ever goes in messages.
        system_: [ { type: "text", text: system, cache_control: { type: "ephemeral" } } ],
        messages:,
        output_config:
      }
      params[:tools] = tools if tools
      if tier.fallbacks
        params[:fallbacks] = :default
        params[:betas] = [ FALLBACK_BETA ]
      end
      params
    end

    def check_stop!(response)
      case response.stop_reason
      when :refusal then raise Refused, "Model declined (#{response.stop_details&.category || 'unspecified'})"
      when :max_tokens then raise Truncated, "Response hit max_tokens"
      end
    end

    def record(task, tier, started:, response: nil, error: nil)
      usage = response&.usage
      tokens = {
        input_tokens: usage&.input_tokens.to_i, output_tokens: usage&.output_tokens.to_i,
        cache_read_tokens: usage&.cache_read_input_tokens.to_i, cache_write_tokens: usage&.cache_creation_input_tokens.to_i
      }
      LlmCall.create!(
        recommendation_batch: @batch, task: task.to_s, tier: tier.name,
        model: response&.model&.to_s.presence || tier.model,
        **tokens, cost_usd: cost(tier, tokens),
        latency_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round,
        stop_reason: response&.stop_reason&.to_s, error: error&.message&.truncate(1_000)
      )
    rescue ActiveRecord::ActiveRecordError => e
      Rails.error.report(e, handled: true) # logging must never break the call
    end

    def cost(tier, t)
      p = tier.prices
      (t[:input_tokens] * p[:input] + t[:output_tokens] * p[:output] +
        t[:cache_read_tokens] * p[:cache_read] + t[:cache_write_tokens] * p[:cache_write]) / 1_000_000.0
    end
  end
end
