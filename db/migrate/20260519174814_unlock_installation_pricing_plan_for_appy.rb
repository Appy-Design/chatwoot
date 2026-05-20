class UnlockInstallationPricingPlanForAppy < ActiveRecord::Migration[7.1]
  def up
    return unless ENV['APPY_INSTALLATION'].to_s == 'true'

    plan = InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')
    plan.update!(value: 'enterprise') if plan && plan.value == 'community'

    qty = InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')
    qty.update!(value: 1000) if qty && qty.value.to_i < 1000
  end

  def down
    return unless ENV['APPY_INSTALLATION'].to_s == 'true'

    plan = InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')
    plan.update!(value: 'community') if plan

    qty = InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')
    qty.update!(value: 0) if qty
  end
end
