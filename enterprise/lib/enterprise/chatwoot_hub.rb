module Enterprise::ChatwootHub
  ENTERPRISE_BASE_URL = 'https://hub.2.chatwoot.com'.freeze

  def base_url
    return ENV.fetch('CHATWOOT_HUB_URL', ENTERPRISE_BASE_URL) if Rails.env.development?

    ENTERPRISE_BASE_URL
  end

  # Appy fork: short-circuit all phone-home calls to hub.2.chatwoot.com.
  # The hub responds to pings from "tampered" installations (those that
  # have INSTALLATION_PRICING_PLAN set to a paid tier without a matching
  # licence) with a payload that drives the dashboard to render an
  # "Unauthorized premium changes detected — please upgrade" banner and
  # hides plan-gated UI like Captain's FAQ / Documents tabs.
  #
  # Our fork is a legitimately self-hosted installation with no licence
  # to validate. The DISABLE_TELEMETRY env var in upstream only skips the
  # metrics merge — the ping itself still goes out and is enough for the
  # hub to flag the install. So we override here to make the network
  # calls genuine no-ops when the Appy gate is on.
  #
  # Reversible: setting APPY_INSTALLATION=false (or unsetting it) restores
  # upstream behaviour, matching the rest of the fork's gate model.
  def sync_with_hub
    return {} if appy_telemetry_disabled?

    super
  end

  def emit_event(_event_name, _event_data)
    return if appy_telemetry_disabled?

    super
  end

  def register_instance(_company_name, _owner_name, _owner_email)
    return if appy_telemetry_disabled?

    super
  end

  def send_push(_fcm_options)
    # Push notifications via Chatwoot's hub are bundled with the same
    # telemetry channel and require a server-side relay we don't use
    # (we deliver email via SMTP and don't ship a mobile app). No-op
    # to avoid the same identification fingerprint.
    return if appy_telemetry_disabled?

    super
  end

  private

  def appy_telemetry_disabled?
    ENV['APPY_INSTALLATION'].to_s == 'true'
  end
end
