class SetAppyBrandNames < ActiveRecord::Migration[7.1]
  APPY_NAME = 'Appy Support'.freeze

  def up
    return unless ENV['APPY_INSTALLATION'].to_s == 'true'

    set_if_default('INSTALLATION_NAME', 'Chatwoot', APPY_NAME)
    set_if_default('BRAND_NAME', 'Chatwoot', APPY_NAME)

    # Clear the chatwoot.com brand URLs so the "Powered by Appy Support"
    # footer link does not redirect customers to chatwoot.com. Operators
    # can fill these in via Super Admin → App Configs once Appy URLs exist.
    set_if_default('BRAND_URL', 'https://www.chatwoot.com', '')
    set_if_default('WIDGET_BRAND_URL', 'https://www.chatwoot.com', '')
    set_if_default('TERMS_URL', 'https://www.chatwoot.com/terms-of-service', '')
    set_if_default('PRIVACY_URL', 'https://www.chatwoot.com/privacy-policy', '')
  end

  def down
    return unless ENV['APPY_INSTALLATION'].to_s == 'true'

    set_if_default('INSTALLATION_NAME', APPY_NAME, 'Chatwoot')
    set_if_default('BRAND_NAME', APPY_NAME, 'Chatwoot')
    set_if_default('BRAND_URL', '', 'https://www.chatwoot.com')
    set_if_default('WIDGET_BRAND_URL', '', 'https://www.chatwoot.com')
    set_if_default('TERMS_URL', '', 'https://www.chatwoot.com/terms-of-service')
    set_if_default('PRIVACY_URL', '', 'https://www.chatwoot.com/privacy-policy')
  end

  private

  def set_if_default(key, expected, new_value)
    config = InstallationConfig.find_by(name: key)
    config.update!(value: new_value) if config && config.value == expected
  end
end
