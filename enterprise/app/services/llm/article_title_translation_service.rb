# frozen_string_literal: true

# Translates a single short string (typically a helpcenter article title)
# from one locale to another using the configured Captain LLM provider.
#
# Appy fork — surfaces an English hint next to non-English article titles
# in the article translation linker so ops can identify cross-locale
# matches without leaving the editor.
class Llm::ArticleTitleTranslationService < Llm::BaseAiService
  MAX_INPUT_LENGTH = 512

  def call(text:, target_locale:, source_locale: nil)
    text = text.to_s.strip
    return '' if text.empty?
    return text if source_locale.present? && source_locale == target_locale

    truncated = text.length > MAX_INPUT_LENGTH ? text[0, MAX_INPUT_LENGTH] : text
    chat.with_temperature(0.2).ask(prompt(truncated, target_locale, source_locale)).content.to_s.strip
  end

  private

  def prompt(text, target_locale, source_locale)
    <<~PROMPT
      Translate the following short text into #{target_locale}. Output ONLY the translated text — no quotes, no explanation, no leading or trailing whitespace.
      #{source_locale ? "Source locale: #{source_locale}." : ''}
      Text: #{text}
    PROMPT
  end
end
