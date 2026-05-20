# Appy Support — Fork Guide

This is the [Appy-Design/chatwoot](https://github.com/Appy-Design/chatwoot) fork of [chatwoot/chatwoot](https://github.com/chatwoot/chatwoot). It's customised for our internal use and deployed as `ghcr.io/appy-design/chatwoot` on our IONOS VPS.

This document covers fork-specific behavior. For upstream functionality see the original [README.md](./README.md) and [chatwoot.com/help-center](https://www.chatwoot.com/help-center).

## Contents

- [Branching model + image releases](#branching-model--image-releases)
- [Required environment](#required-environment)
- [Branding](#branding)
- [Captain — OpenAI + Anthropic](#captain--openai--anthropic)
- [Help center admin search](#help-center-admin-search)
- [Paid feature unlock](#paid-feature-unlock)
- [Local dev (Docker)](#local-dev-docker)
- [Production cutover (IONOS VPS)](#production-cutover-ionos-vps)
- [Syncing upstream Chatwoot fixes](#syncing-upstream-chatwoot-fixes)

---

## Branching model + image releases

| Branch | Purpose |
|---|---|
| `main` | Production tracker. Tagged releases (`vX.Y.Z`) are cut from here. |
| `develop` | Upstream-sync staging. We merge `chatwoot/develop` here, resolve conflicts, then PR into `main`. |
| `appy/<topic>` | Feature work. PR into `main`. |

GHCR images are built by `.github/workflows/publish_appy_docker.yml`:

| Trigger | Tag | Purpose |
|---|---|---|
| PR opened/updated against `main` or `develop` | `pr-<number>` | Preview / on-VPS staging |
| Tag push `vX.Y.Z` (reachable from `main`) | `vX.Y.Z` + `latest` | Production release |
| Manual `workflow_dispatch` | user-supplied | Hot-fixes |

Images are multi-arch (`linux/amd64` + `linux/arm64`). Auth uses the workflow's `GITHUB_TOKEN` — no secrets need to be configured.

## Required environment

These envs are unique to the Appy fork. Set them in `.env` (dev) or your VPS env (prod):

| Var | Required | What it does |
|---|---|---|
| `APPY_INSTALLATION=true` | Yes | Master switch — gates all the fork-specific UI scrubs and the migration that unlocks plan-gated features. Set to anything else (or unset) to behave like vanilla Chatwoot. |
| `INSTALLATION_NAME=Appy Support` | Yes | Customer-facing brand. Swapped in automatically wherever `replaceInstallationName` or the backend `Branding::InstallationNameService` is used. |
| `INSTALLATION_PRICING_PLAN=enterprise` | Yes | Overrides `ChatwootHub.pricing_plan`. The provided migration sets this in the DB too on first run. |
| `INSTALLATION_PRICING_PLAN_QUANTITY=1000` | Yes | High value so we don't trip seat limits. |
| `RAILS_HOST_PORT=3001` | Optional | Move Rails off host port 3000 when something else is using it (useful in local dev). |

Standard Chatwoot env vars (`SECRET_KEY_BASE`, `REDIS_URL`, `POSTGRES_*`, `ACTIVE_RECORD_ENCRYPTION_*`, `SMTP_*`, etc.) still apply — see `.env.example`.

## Branding

Customer-facing surfaces (help center portal, embed widget, CSAT survey, transactional emails) carry the "Appy Support" brand.

**Where the brand name comes from**: `INSTALLATION_NAME` env → seeded into `InstallationConfig` → exposed to the frontend via `window.globalConfig.INSTALLATION_NAME` and to the backend via `Branding::InstallationNameService.installation_name`. The Vue composable `useBranding.replaceInstallationName` swaps the literal `"Chatwoot"` in any i18n string with the configured name.

**Where the logos come from**: `public/brand-assets/logo.svg`, `logo_dark.svg`, `logo_thumbnail.svg`. They currently render text-only placeholders (`Appy Support`). To install real logos: drop SVGs (same dimensions, same filenames) at the same paths and rebuild the image. No code change needed.

**URLs in the footer**: `BRAND_URL`, `WIDGET_BRAND_URL`, `TERMS_URL`, `PRIVACY_URL` are blank by default in the fork (the install migration clears the chatwoot.com defaults). Set them via **Super Admin → App Configs** once you have Appy URLs to point at.

What's NOT rebranded (deliberate, to keep upstream-sync clean):
- Super admin / internal admin pages
- README, contributor docs
- Source-code references to "Chatwoot" / "chatwoot.com" that aren't user-visible

## Captain — OpenAI + Anthropic

Each Captain assistant can pick its LLM provider — OpenAI or Anthropic Claude — independently. NULL provider falls back to the installation default (OpenAI).

**Setting up keys** (Super Admin → App Configs):

| Key | What it is |
|---|---|
| `CAPTAIN_OPEN_AI_API_KEY` | OpenAI key |
| `CAPTAIN_OPEN_AI_MODEL` | OpenAI default model (e.g. `gpt-4.1-mini`) |
| `CAPTAIN_ANTHROPIC_API_KEY` | Anthropic key |
| `CAPTAIN_ANTHROPIC_MODEL` | Anthropic default model (default `claude-sonnet-4-5`) |

**Per-assistant config**:

1. Dashboard → Settings → Captain → pick an assistant → **Basic settings**.
2. **AI provider** dropdown: `Use installation default` (= OpenAI), `OpenAI`, or `Anthropic (Claude)`.
3. **Model override** text field: leave blank to use the installation default for that provider, or enter an explicit model name (e.g. `gpt-4o`, `claude-opus-4`).
4. Save. Subsequent Captain responses for that assistant will route through the chosen provider.

Under the hood the resolution is:

```text
assistant.provider     → 'anthropic' | 'openai' | nil (= openai)
assistant.model_override → explicit model | nil
nil model_override → installation default for that provider
no installation default → hardcoded fallback (gpt-4.1-mini | claude-sonnet-4-5)
```

Verification (Rails console):

```sh
docker compose exec rails bundle exec rails runner "
  a = Captain::Assistant.first
  s = Llm::BaseAiService.new(assistant: a)
  puts \"provider=#{s.provider} model=#{s.model}\"
"
```

## Help center admin search

The admin article list (Help Center → Portal → Articles) has a search input at the top. Type a partial article title; results filter live with a 300ms debounce. Scope is the **current portal + locale + status tab** (Published / Draft / Archived). Switching tabs clears the search.

The search hits the existing `/articles?query=` endpoint, which is backed by Postgres full-text search weighted by title (A), description (B), content (C). Title matches rank top, so the UX is title-search-like even though technically other fields can match too.

State is in-memory only — refresh clears the search.

## Paid feature unlock

`APPY_INSTALLATION=true` plus `INSTALLATION_PRICING_PLAN=enterprise` unlocks plan-gated features (SAML SSO, multi-portal, multi-locale, custom domains, audio transcription, etc.) and hides upgrade prompts.

What's gated specifically:
- Super admin "Upgrade now" button (hidden)
- Help-center `UpgradePage` (never routed to)
- Dashboard-wide upgrade page (`Dashboard.vue` bypasses when `appyInstallation` is true)
- Captain `LimitBanner`s (FAQ + Document) — banners never render
- `BasePaywallModal` — modal never renders

All gates check `appyInstallation` at render time, so unsetting `APPY_INSTALLATION=false` (or removing the env) restores upstream UI in full. Reversible by design.

The plan flag itself is set by the `UnlockInstallationPricingPlanForAppy` migration. It only runs when `APPY_INSTALLATION=true` and only updates rows that are still at the `community` default — idempotent and safe to re-run.

## Local dev (Docker)

The fork is developed in Docker via the existing `docker-compose.yaml` (volume-mounts `./:/app:delegated`). A committed `docker-compose.override.yaml` sets `POSTGRES_HOST_AUTH_METHOD=trust` so `pgvector/pg16` accepts the empty default password.

**One-time setup**

```sh
# .env values (see "Required environment" above, plus generated secrets)
SECRET_KEY_BASE=$(openssl rand -hex 64) >> .env
REDIS_PASSWORD=$(openssl rand -hex 16) >> .env
# ...and all the other entries from .env.example

# Build the base image first (rails + vite images derive from it)
docker compose build base
docker compose build rails vite

# Bring up data services and generate Active Record encryption keys
docker compose up -d postgres redis mailhog
docker compose run --rm --no-deps rails bundle exec rails db:encryption:init
# Paste the three printed keys into .env

# Load schema + seed
docker compose run --rm --no-deps rails bundle exec rails db:drop db:create db:schema:load db:seed
```

(We use `db:schema:load` instead of `db:migrate` because an upstream historic migration references a now-removed `ActsAsTaggableOn::Taggable::Cache` constant.)

**Daily**

```sh
docker compose up           # foreground
docker compose up -d        # background
docker compose logs -f rails vite
docker compose down         # stop all
```

Endpoints: app `http://localhost:${RAILS_HOST_PORT:-3000}` · Mailhog `http://localhost:8025` · Vite `http://localhost:3036`.

**Seeded login**: `john@acme.inc` / `Password1!`.

**Rails CLI**: `docker compose exec rails bundle exec rails <cmd>` for running containers, or `docker compose run --rm --no-deps rails bundle exec rails <cmd>` for one-shots (the `--no-deps` flag avoids re-creating sidekiq/vite, which can hit a known macOS pnpm-symlink issue when populating fresh node_modules volumes).

## Production cutover (IONOS VPS)

Image pulls + deploy on the VPS are **manual** by design. CI publishes images; the operator decides when to roll.

**One-time setup on the VPS**

1. Create a fine-grained GitHub Personal Access Token with `read:packages` scope, limited to the `Appy-Design/chatwoot` package.
2. Log Docker into GHCR:
   ```sh
   echo $PAT | docker login ghcr.io -u <gh-username> --password-stdin
   ```
3. In your `docker-compose.production.yaml`, change `image: chatwoot/chatwoot:latest` → `image: ghcr.io/appy-design/chatwoot:v1.0.0` (always pin to a specific tag, never `latest`).
4. Set the Appy envs in your VPS env file:
   ```env
   APPY_INSTALLATION=true
   INSTALLATION_NAME=Appy Support
   INSTALLATION_PRICING_PLAN=enterprise
   INSTALLATION_PRICING_PLAN_QUANTITY=1000
   ```
5. Take a Postgres dump for safety: `pg_dump -Fc -f appy-pre-cutover.dump chatwoot`.

**Each release**

```sh
# 1. Bump the image tag in docker-compose.production.yaml to the new vX.Y.Z

# 2. Pull
docker compose pull

# 3. Run migrations
docker compose run --rm rails bundle exec rails db:migrate

# 4. Rolling restart
docker compose up -d

# 5. Health check
curl -fsSL https://<your-domain>/api && echo OK
```

**Rollback**

1. Revert the tag in `docker-compose.production.yaml` to the previous `vX.Y.Z`.
2. `docker compose pull && docker compose up -d`.
3. If a migration broke compatibility (unlikely — all Appy migrations are additive), restore from the dump.

## Syncing upstream Chatwoot fixes

1. Add an upstream remote once: `git remote add upstream https://github.com/chatwoot/chatwoot.git`.
2. Fetch and merge into `develop`:
   ```sh
   git fetch upstream
   git checkout develop
   git merge upstream/develop
   ```
3. Resolve conflicts. Hot spots historically:
   - `docker-compose.yaml` (we added `RAILS_HOST_PORT`)
   - `config/installation_config.yml` (we flipped `INSTALLATION_PRICING_PLAN` default)
   - `lib/llm/config.rb` (we added `anthropic_api_key`)
   - `enterprise/app/services/llm/base_ai_service.rb` (we accept `assistant:`)
   - Files in `app/javascript/dashboard/routes/dashboard/Dashboard.vue` and `helpcenter/pages/HelpCenterPageRouteView.vue` (we added `appyInstallation` gates)
4. Open a PR `develop` → `main`. Once merged, cut a new `vX.Y.Z` tag from `main`.

Workflows `publish_foss_docker.yml` and `publish_ee_docker.yml` are kept intact but guarded by `if: ${{ false }}` so they never run. **Don't delete or rename them** — that creates merge conflicts on every upstream sync.
