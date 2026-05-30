require 'ruby_llm'

module Llm::Config
  DEFAULT_MODEL = 'gpt-4.1-mini'.freeze

  class << self
    def initialized?
      @initialized ||= false
    end

    def initialize!
      return if @initialized

      configure_ruby_llm
      @initialized = true
    end

    def reset!
      @initialized = false
    end

    def with_api_key(api_key, api_base: nil)
      initialize!
      context = RubyLLM.context do |config|
        config.openai_api_key = api_key
        config.openai_api_base = api_base
      end

      yield context
    end

    private

    def configure_ruby_llm
      RubyLLM.configure do |config|
        config.openai_api_key = system_api_key if system_api_key.present?
        config.openai_api_base = openai_endpoint.chomp('/') if openai_endpoint.present?
        config.anthropic_api_key = anthropic_api_key if anthropic_api_key.present?
        config.model_registry_file = Rails.root.join('config/llm_models.json').to_s
        config.logger = Rails.logger
      end
    end

    # Appy fork: each lookup tries the InstallationConfig DB row first
    # (Super Admin → App Configs), then the CAPTAIN_* env var (matches
    # APPY.md), then RubyLLM's native env names (so a single
    # OPENAI_API_KEY / ANTHROPIC_API_KEY also works).
    #
    # Without this chain, ENV-only configuration was silently ignored —
    # configure_ruby_llm above only sets values that resolve here, and the
    # legacy Captain code paths (Copilot, FAQ generator, Memory) go
    # through this initializer, not the newer RubyLLM-native auto-config.
    def system_api_key
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value.presence ||
        ENV['CAPTAIN_OPEN_AI_API_KEY'].presence ||
        ENV.fetch('OPENAI_API_KEY', nil).presence
    end

    def openai_endpoint
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value.presence ||
        ENV['CAPTAIN_OPEN_AI_ENDPOINT'].presence ||
        ENV.fetch('OPENAI_API_BASE', nil).presence
    end

    def anthropic_api_key
      InstallationConfig.find_by(name: 'CAPTAIN_ANTHROPIC_API_KEY')&.value.presence ||
        ENV['CAPTAIN_ANTHROPIC_API_KEY'].presence ||
        ENV.fetch('ANTHROPIC_API_KEY', nil).presence
    end
  end
end
