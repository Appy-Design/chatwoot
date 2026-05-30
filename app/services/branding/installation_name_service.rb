# frozen_string_literal: true

# Backend counterpart to the JS `useBranding.replaceInstallationName` composable.
# Swaps the literal word "Chatwoot" with the configured installation name.
module Branding::InstallationNameService
  DEFAULT_NAME = 'Chatwoot'

  def self.replace(text)
    return text if text.blank?

    name = installation_name
    return text if name.blank? || name == DEFAULT_NAME

    text.gsub(DEFAULT_NAME, name)
  end

  def self.installation_name
    InstallationConfig.find_by(name: 'INSTALLATION_NAME')&.value.presence ||
      ENV['INSTALLATION_NAME'].presence ||
      DEFAULT_NAME
  end
end
