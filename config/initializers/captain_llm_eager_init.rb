# frozen_string_literal: true

# Appy fork: eager-initialize Llm::Config at boot so RubyLLM's global
# configuration is populated before any code path needs it. Upstream
# Chatwoot lazily configures RubyLLM only when Llm::BaseAiService is
# instantiated, which means the newer "Captain V2" agents runtime
# (which calls RubyLLM directly, bypassing BaseAiService) sees an
# unconfigured client and raises `RubyLLM::ConfigurationError`.
#
# Booting eagerly here costs ~one DB lookup at startup and removes the
# race entirely. Wrapped in `to_prepare` so dev-mode autoload reloads
# also re-initialize (matters when DB rows change in dev).
Rails.application.config.to_prepare do
  Llm::Config.reset!
  Llm::Config.initialize!
rescue StandardError => e
  # Don't crash boot if the DB isn't ready (e.g. assets:precompile,
  # db:migrate before configs are seeded). The lazy paths still work.
  Rails.logger.warn("Llm::Config eager init skipped: #{e.class}: #{e.message}")
end
