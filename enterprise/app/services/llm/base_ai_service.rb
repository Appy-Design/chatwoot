# frozen_string_literal: true

# Base service for LLM operations using RubyLLM.
# New features should inherit from this class.
class Llm::BaseAiService
  DEFAULT_TEMPERATURE = 1.0
  OPENAI_FALLBACK_MODEL = Llm::Config::DEFAULT_MODEL
  ANTHROPIC_FALLBACK_MODEL = 'claude-sonnet-4-5'

  attr_reader :model, :temperature, :provider

  def initialize(assistant: nil)
    Llm::Config.initialize!
    @assistant = assistant
    setup_provider_and_model
    setup_temperature
  end

  def chat(model: @model, temperature: @temperature, provider: @provider)
    RubyLLM.chat(model: model, provider: provider).with_temperature(temperature)
  end

  private

  # Strips markdown code fences (```json ... ``` or ``` ... ```) that some
  # LLM providers/gateways wrap around JSON responses despite response_format hints.
  def sanitize_json_response(response)
    return response if response.nil?

    response.strip.sub(/\A```(?:\w*)\s*\n?/, '').sub(/\n?\s*```\s*\z/, '').strip
  end

  def setup_provider_and_model
    @provider = (@assistant&.provider.presence || 'openai').to_sym
    @model = @assistant&.model_override.presence || installation_default_model
  end

  def installation_default_model
    config_key = @provider == :anthropic ? 'CAPTAIN_ANTHROPIC_MODEL' : 'CAPTAIN_OPEN_AI_MODEL'
    InstallationConfig.find_by(name: config_key)&.value.presence || fallback_model
  end

  def fallback_model
    @provider == :anthropic ? ANTHROPIC_FALLBACK_MODEL : OPENAI_FALLBACK_MODEL
  end

  def setup_temperature
    @temperature = DEFAULT_TEMPERATURE
  end
end
