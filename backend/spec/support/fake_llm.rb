# Test doubles shaped like the anthropic SDK's response objects, plus a scripted
# Llm::Client stand-in. Tests never call a real model.
module FakeLlm
  Usage = Struct.new(:input_tokens, :output_tokens, :cache_read_input_tokens, :cache_creation_input_tokens,
                     keyword_init: true)
  StopDetails = Struct.new(:category, keyword_init: true)
  Block = Struct.new(:type, :text, :id, :name, :input, keyword_init: true) do
    def to_h = super.compact
  end
  Response = Struct.new(:content, :stop_reason, :usage, :model, :stop_details, keyword_init: true)

  module_function

  def usage(input = 100, output = 50) = Usage.new(input_tokens: input, output_tokens: output,
                                                  cache_read_input_tokens: 0, cache_creation_input_tokens: 0)

  def text(body, stop: :end_turn, model: "claude-haiku-5-5")
    Response.new(content: [ Block.new(type: :text, text: body) ], stop_reason: stop, usage: usage, model:)
  end

  # tool_use(["search_candidates", {...}], ["summarize_reader", {}])
  def tool_use(*calls)
    blocks = calls.each_with_index.map { |(name, input), i| Block.new(type: :tool_use, id: "tu_#{name}_#{i}", name:, input:) }
    Response.new(content: blocks, stop_reason: :tool_use, usage: usage, model: "claude-sonnet-5-5")
  end

  # Scripted replacement for Llm::Client: `create` pops orchestrator turns in order;
  # `json` answers per task (a value, or a lambda receiving the input and call count).
  class Client
    attr_reader :created, :json_calls

    def initialize(turns: [], json: {})
      @turns = turns.dup
      @json = json
      @created = []
      @json_calls = Hash.new { |h, k| h[k] = [] }
    end

    def create(**params)
      @created << params
      @turns.shift || raise("FakeLlm: no scripted turn left")
    end

    def json(task:, input:, **)
      @json_calls[task] << input
      answer = @json.fetch(task) { raise "FakeLlm: no json answer for #{task}" }
      answer.respond_to?(:call) ? answer.call(input, @json_calls[task].size) : answer
    end
  end
end
