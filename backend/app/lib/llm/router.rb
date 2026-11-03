module Llm
  Tier = Data.define(:name, :model, :effort, :fallbacks, :prices)

  # Resolves a task to its model tier from config/llm.yml. The allowlist lives in config,
  # not in callers, so no code branches on model names.
  #
  #   Llm::Router.for(:rank_candidates).model # => "claude-opus-5-5"
  module Router
    class UnknownTask < KeyError; end

    module_function

    def for(task)
      tier_name = config.fetch("tasks").fetch(task.to_s) { raise UnknownTask, "No LLM tier for task #{task.inspect}" }
      tier(tier_name)
    end

    def tier(name)
      t = config.fetch("tiers").fetch(name.to_s)
      Tier.new(name: name.to_s, model: t.fetch("model"), effort: t.fetch("effort"),
               fallbacks: t.fetch("fallbacks"), prices: t.fetch("usd_per_mtok").transform_keys(&:to_sym))
    end

    def agent_limits = config.fetch("agent")
    def prompt_version = config.fetch("prompt_version")
    def tasks_on(tier_name) = config.fetch("tasks").select { |_, t| t == tier_name.to_s }.keys

    def config
      @config ||= YAML.load_file(Rails.root.join("config/llm.yml")).freeze
    end

    def reset! = @config = nil
  end
end
