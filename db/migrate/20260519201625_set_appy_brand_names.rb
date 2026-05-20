class SetAppyBrandNames < ActiveRecord::Migration[7.1]
  APPY_NAME = 'Appy Support'.freeze

  def up
    return unless ENV['APPY_INSTALLATION'].to_s == 'true'

    set_if_default('INSTALLATION_NAME', 'Chatwoot', APPY_NAME)
    set_if_default('BRAND_NAME', 'Chatwoot', APPY_NAME)
  end

  def down
    return unless ENV['APPY_INSTALLATION'].to_s == 'true'

    set_if_default('INSTALLATION_NAME', APPY_NAME, 'Chatwoot')
    set_if_default('BRAND_NAME', APPY_NAME, 'Chatwoot')
  end

  private

  def set_if_default(key, expected, new_value)
    config = InstallationConfig.find_by(name: key)
    config.update!(value: new_value) if config && config.value == expected
  end
end
