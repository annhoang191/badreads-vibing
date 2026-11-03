module Llm
  # Loads a static, versioned system prompt from app/prompts/<task>.md. Prompts are kept
  # byte-stable (no interpolation) so the prompt cache works; per-user data goes in messages.
  module Prompt
    module_function

    def for(task)
      cache[task.to_s] ||= Rails.root.join("app/prompts/#{task}.md").read.freeze
    end

    def cache = @cache ||= {}
  end
end
