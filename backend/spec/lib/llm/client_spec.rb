require "rails_helper"

RSpec.describe Llm::Client do
  let(:messages_api) { double("messages") }
  let(:anthropic) { double("anthropic", beta: double("beta", messages: messages_api)) }
  let(:batch) { create(:recommendation_batch) }
  let(:client) { described_class.new(batch:, anthropic:) }

  it "uses the task's tier, enables fallbacks on Sonnet/Opus, and logs cost" do
    expect(messages_api).to receive(:create) do |**params|
      expect(params).to include(model: :"claude-opus-5-5", fallbacks: :default, betas: [ described_class::FALLBACK_BETA ])
      expect(params[:output_config]).to eq(effort: :high, format_: { type: :json_schema, schema: { type: "object" } })
      expect(params[:system_].first).to include(cache_control: { type: "ephemeral" })
      FakeLlm.text('{"ok":true}', model: "claude-opus-5-5")
    end

    expect(client.json(task: :rank_candidates, system: "s", input: {}, schema: { type: "object" })).to eq("ok" => true)
    call = LlmCall.last
    expect(call).to have_attributes(task: "rank_candidates", tier: "complex", model: "claude-opus-5-5",
                                    input_tokens: 100, output_tokens: 50, recommendation_batch_id: batch.id)
    expect(call.cost_usd.to_f).to be_within(1e-9).of((100 * 4.0 + 50 * 20.0) / 1_000_000)
  end

  it "does not send fallbacks for Haiku" do
    expect(messages_api).to receive(:create) do |**params|
      expect(params).to include(model: :"claude-haiku-5-5")
      expect(params).not_to include(:fallbacks, :betas)
      FakeLlm.text('{"queries":[]}')
    end
    client.json(task: :expand_queries, system: "s", input: {}, schema: {})
  end

  it "raises Refused on a refusal and still logs the call" do
    allow(messages_api).to receive(:create).and_return(
      FakeLlm::Response.new(content: [], stop_reason: :refusal, usage: FakeLlm.usage, model: "claude-opus-5-5",
                            stop_details: FakeLlm::StopDetails.new(category: :cyber))
    )
    expect { client.create(task: :rank_candidates, system: "s", messages: [], max_tokens: 10) }
      .to raise_error(described_class::Refused, /cyber/)
    expect(LlmCall.last.stop_reason).to eq("refusal")
  end

  it "raises Truncated on max_tokens" do
    allow(messages_api).to receive(:create).and_return(FakeLlm.text("{", stop: :max_tokens))
    expect { client.json(task: :expand_queries, system: "s", input: {}, schema: {}) }.to raise_error(described_class::Truncated)
  end

  it "raises InvalidJson on unparseable output" do
    allow(messages_api).to receive(:create).and_return(FakeLlm.text("not json"))
    expect { client.json(task: :expand_queries, system: "s", input: {}, schema: {}) }.to raise_error(described_class::InvalidJson)
  end

  it "wraps SDK errors and logs them" do
    allow(messages_api).to receive(:create).and_raise(Anthropic::Errors::APIConnectionError.new(url: "https://api", request: nil))
    expect { client.create(task: :summarize_reader, system: "s", messages: [], max_tokens: 10) }
      .to raise_error(described_class::Error)
    expect(LlmCall.last.error).to be_present
  end
end
