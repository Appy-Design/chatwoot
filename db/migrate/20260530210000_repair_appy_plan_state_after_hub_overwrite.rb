class RepairAppyPlanStateAfterHubOverwrite < ActiveRecord::Migration[7.1]
  # Only disable_branding is re-enabled here. The other premium features
  # (audit_logs, sla, custom_roles, captain_integration, csat_review_notes,
  # conversation_required_attributes) stay disabled because the fork is
  # replacing them with OSS-layer equivalents — Appy Copilot for Captain,
  # follow-ups for the rest. Re-enabling Chatwoot's enterprise versions
  # would defeat the point of the rebuild and reintroduce the licence
  # question.
  PREMIUM_FEATURES_TO_RE_ENABLE = %w[
    disable_branding
  ].freeze

  # Appy fork: Chatwoot's daily Internal::CheckNewVersionsJob phones home,
  # receives `plan: "community"` for our (legitimately self-hosted, no
  # license) installation, overwrites INSTALLATION_PRICING_PLAN with
  # "community" + locks the row, then calls ReconcilePlanConfigService
  # which:
  #   - sets the "Unauthorized premium changes detected" Redis warning,
  #   - resets premium InstallationConfig rows to community defaults
  #     (notably INSTALLATION_NAME back to "Chatwoot"), and
  #   - disables every premium feature on every Account, including
  #     disable_branding — which is why "Chatwoot" branding starts
  #     bleeding through where we previously had Appy Support.
  #
  # The accompanying override in enterprise/lib/enterprise/chatwoot_hub.rb
  # neuters sync_with_hub so this never happens again. This migration
  # repairs the existing damage on installations where the daily job
  # already ran before the override shipped:
  #   - re-sets the pricing plan + quantity rows to the Appy defaults
  #     and unlocks them,
  #   - clears the Redis warning flag,
  #   - re-enables ONLY disable_branding on every Account (see comment
  #     on the constant above for why other premium features stay off).
  #
  # Idempotent: if the plan row is already "enterprise" with the right
  # quantity and disable_branding is already enabled, nothing changes.
  def up
    return unless ENV['APPY_INSTALLATION'].to_s == 'true'

    repair_pricing_plan_row
    repair_pricing_plan_quantity_row
    clear_premium_changes_warning
    re_enable_premium_features
  end

  def down
    # No-op: this is a one-way repair migration. The rollback is "revert
    # APPY_INSTALLATION=true" and let the upstream telemetry flow take
    # over again — there's no meaningful inverse operation here.
  end

  private

  def repair_pricing_plan_row
    plan = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN')
    plan.value = 'enterprise'
    plan.locked = false
    plan.save!
  end

  def repair_pricing_plan_quantity_row
    qty = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')
    qty.value = ENV['INSTALLATION_PRICING_PLAN_QUANTITY'].presence&.to_i || 1000
    qty.locked = false
    qty.save!
  end

  def clear_premium_changes_warning
    Redis::Alfred.delete(Redis::Alfred::CHATWOOT_INSTALLATION_CONFIG_RESET_WARNING)
  rescue StandardError => e
    Rails.logger.warn("Skipping warning-flag cleanup: #{e.class}: #{e.message}")
  end

  def re_enable_premium_features
    Account.find_in_batches do |accounts|
      accounts.each do |account|
        account.enable_features!(*PREMIUM_FEATURES_TO_RE_ENABLE)
      end
    end
  rescue StandardError => e
    Rails.logger.warn("Skipping premium-feature re-enable: #{e.class}: #{e.message}")
  end
end
