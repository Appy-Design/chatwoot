# Appy Support — Chatwoot fork design

**Date:** 2026-05-19
**Author:** Luke Walsh (with Claude)
**Status:** Draft — pending implementation plan

## Goal

Customise the `Appy-Design/chatwoot` fork so it serves Appy Support's needs:

1. Customer-facing surfaces re-branded ("Appy Support", not "Chatwoot").
2. Captain AI usable with either OpenAI or Anthropic (Claude), pickable per assistant.
3. "Paid" feature gates removed for our self-hosted install.
4. Search bar added to the help center admin article list.
5. CI/CD that publishes private Docker images to GitHub Container Registry, with a tight, manual swap procedure on the existing IONOS VPS.

Constraints: minimise drift from upstream so we can keep pulling Chatwoot fixes; no rip-and-replace of unrelated code; ship the happy path first.

---

## 1. Branding (customer-facing only)

**Scope:** help center portal, embed widget, survey, customer-visible auth pages (login/signup/password reset), transactional emails. **Out of scope:** super admin, internal admin chrome, README, contributor docs.

**Implementation:**

- Set `INSTALLATION_NAME=Appy Support` in `.env` (already supported).
- Audit hardcoded "Chatwoot" strings in:
  - `app/javascript/portal/**` (help center)
  - `app/javascript/widget/**` (embed widget)
  - `app/javascript/survey/**` (CSAT survey)
  - `app/views/mailers/**` (email templates)
- Replace via `replaceInstallationName()` from `shared/composables/useBranding.js` in Vue templates.
- Add a backend helper `Branding::Replace.installation_name(text)` mirroring the JS composable, for ERB email templates.
- Add an asset slot at `public/brand/` with conventional filenames:
  - `logo.svg`, `logo-dark.svg` (sidebar / portal header)
  - `favicon.ico`
  - `widget-badge.svg` (widget chrome)
  - `email-header.png`
- Update relevant views to load from `public/brand/<file>` if present, else fall back to existing Chatwoot defaults. Assets get dropped in later; no code change required when the artwork arrives.

**Out of scope explicitly:** logos and copy aren't being created in this work; the slot is what's being built.

---

## 2. Help center admin article search

**Pain:** Admins can't search for an article in the help center admin — they must page through manually.

**UX:**

- Search input at the top of the article list in `PortalsArticlesIndexPage.vue`.
- Title-only.
- Debounced 300ms live filter.
- Scoped to the current portal + locale + status tab (Published / Draft / Archived). Switching tabs does not preserve the search query.
- In-memory state only — refresh clears the search. (No URL `?q=` param.)
- Clearing the input restores the unfiltered list.
- Empty state reuses the existing component with a "no matches" message.

**Backend:**

- Existing `ArticlesAPI` already supports a `query` parameter (used by the in-editor `SearchPopover`). The store action is extended to pass `query` through.

---

## 3. Captain — multi-provider (Claude + OpenAI)

**Provider library:** continue using `RubyLLM` (already a dependency).

**Installation config** (set via super admin UI, persisted in `installation_configs` table):

| Key | Default | Notes |
|---|---|---|
| `CAPTAIN_OPEN_AI_API_KEY` | unset | existing |
| `CAPTAIN_OPEN_AI_MODEL` | existing default | existing |
| `CAPTAIN_ANTHROPIC_API_KEY` | unset | new |
| `CAPTAIN_ANTHROPIC_MODEL` | `claude-sonnet-4-5` | new |

Add both Anthropic fields to `config/installation_config.yml` so they appear in the super admin "App Configs" form automatically.

**Per-assistant picker:**

- DB migration adds two nullable columns to `captain_assistants`:
  - `provider` (string, nullable) — `'openai'` or `'anthropic'`
  - `model` (string, nullable) — free-text override
- NULL on both columns means "use the installation default", which preserves current behaviour (OpenAI). Migration is therefore backwards-compatible.
- Frontend: add a provider dropdown + optional model field to the Captain assistant edit form. No new page; two rows added to the existing form.

**Service change:**

- `Llm::BaseAiService#setup_model` (and any subclass that hardcodes the model) reads the assistant's `provider` + `model`, falling back to the installation config.
- `RubyLLM.chat(model:, provider:)` handles both providers transparently. No new service classes needed.

**Auth:** RubyLLM picks up provider credentials from env / config; the InstallationConfig writes them into env at boot (existing pattern).

---

## 4. Paid feature unlock — plan flag + UI scrub

**Plan flag:**

- Set `INSTALLATION_PRICING_PLAN=enterprise` and `INSTALLATION_PRICING_PLAN_QUANTITY` to a high number (e.g. 1000) at install/boot.
- This overrides `ChatwootHub.pricing_plan`. Any non-`community` value unlocks the plan-gated features (SAML SSO, multi-portal, multi-locale, custom domains, audio transcription, etc.). `enterprise` is the most expressive option and matches existing super-admin UI strings.

**UI scrub:**

- Remove the route entry for `app/javascript/dashboard/routes/dashboard/helpcenter/components/UpgradePage.vue` and any links pointing to it. Component file stays (avoids merge churn) but is unreachable.
- Replace the body of `app/views/super_admin/settings/_upgrade_button_enterprise.html.erb` with a guarded no-op when `APPY_INSTALLATION=true`.
- Search for `UPGRADE` i18n keys and `UpgradePage` references; hide CTAs where they appear in customer-facing pages.

**Reversibility:**

- A single `APPY_INSTALLATION=true` env flag gates all UI scrubs. If we ever need to expose an upgrade prompt again, flip the flag.

**Out of scope:**

- Stripe / billing code paths are left intact (not invoked without Stripe webhooks; ripping them out creates merge churn).
- `ChatwootHub` instance registration and version pings stay (they're harmless and we may want version-update awareness).

---

## 5. Local dev — Docker compose, volume mounted

**Setup:**

- Use the existing `docker-compose.yaml` (already volume-mounts the working copy at `./:/app:delegated` and wires up Rails, Sidekiq, Vite, Postgres 16 (pgvector), Redis, Mailhog).
- Create `.env` from `.env.example` with:
  - `SECRET_KEY_BASE` (generated with `rake secret`)
  - `INSTALLATION_NAME=Appy Support`
  - `INSTALLATION_PRICING_PLAN=enterprise`
  - `INSTALLATION_PRICING_PLAN_QUANTITY=1000`
  - `APPY_INSTALLATION=true`
  - Active Record encryption keys (generated via `rails db:encryption:init`)
  - Redis password (any value)
  - Postgres connection (defaults from compose)
- One-time bootstrap inside containers: `bundle install`, `pnpm install`, `db:create db:migrate db:seed`.
- Gems and `node_modules` persist in named volumes (defined in compose).

**Daily workflow:**

```sh
docker compose up        # all services
# Rails at http://localhost:3000
# Mailhog at http://localhost:8025
```

Edits to local files are picked up live by Vite HMR and Rails dev reload.

---

## 6. CI/CD — GHCR images, branching, versioning

**Branching:**

- Default branch renamed from `master` → `main`. `main` is the production tracker.
- `develop` is kept as the upstream-sync branch — we merge `chatwoot/develop` here, resolve conflicts, then PR to `main`.
- Day-to-day work: feature branch → PR into `main` → merge → tag (`vX.Y.Z`) → release.

**Image strategy:** All images published to `ghcr.io/appy-design/chatwoot`.

| Trigger | Tags | Purpose |
|---|---|---|
| PR open or update (base = `main` or `develop`) | `pr-<number>` (overwritten per push) | Preview / on-VPS staging |
| Tag push matching `v*` (must be on a commit reachable from `main`) | `vX.Y.Z` + `latest` | Production release |
| `workflow_dispatch` (manual) | user-specified | Hot-fixes / re-builds |

- **No** image build on plain pushes to `main` (require a tag to release).
- **No** image build on plain pushes to `develop` (avoids noise).

**Workflow file:** new `.github/workflows/publish_appy_docker.yml`, modeled on `publish_foss_docker.yml`:

- Multi-arch: `linux/amd64` + `linux/arm64` (matrix), merged via `docker buildx imagetools`.
- Uses the existing `docker/Dockerfile`; **does not** strip `enterprise/` (we want EE behaviour).
- Auth via `GITHUB_TOKEN` with `packages: write` job permission. No PAT needed for the build itself.

**Disabled workflows:** the existing `publish_foss_docker.yml` and `publish_ee_docker.yml` push to upstream's DockerHub using credentials we don't have. They're disabled with an `if: false` job guard so they never run but stay diffable against upstream (avoids file-rename merge conflicts on upstream syncs).

---

## 7. VPS swap procedure (manual, controlled by Luke)

**Image swap is intentionally manual** — no SSH-from-CI auto-deploy. The CI publishes images; the operator decides when to pull on the VPS.

### One-time setup on the IONOS VPS

1. Create a **fine-grained GitHub Personal Access Token**:
   - Scope: `read:packages` only.
   - Resource: limited to the `Appy-Design/chatwoot` package.
2. Log Docker into GHCR on the VPS:
   ```sh
   echo $PAT | docker login ghcr.io -u <gh-username> --password-stdin
   ```
   (Writes to `~/.docker/config.json` on the VPS.)
3. Edit `docker-compose.production.yaml` on the VPS:
   - Change `image: chatwoot/chatwoot:latest` → `image: ghcr.io/appy-design/chatwoot:v1.0.0` (pin to a specific version, not `latest`).
4. Take a Postgres dump as backup before first cutover.

### Each release

1. SSH to the VPS.
2. Bump the image tag in `docker-compose.production.yaml` to the new `vX.Y.Z`.
3. `docker compose pull`
4. Run migrations:
   ```sh
   docker compose run --rm rails bundle exec rails db:migrate
   ```
5. Rolling restart:
   ```sh
   docker compose up -d
   ```
6. Health-check:
   ```sh
   curl -fsSL https://<your-domain>/api && echo OK
   ```

### Rollback

1. Revert the tag in `docker-compose.production.yaml` to the previous `vX.Y.Z`.
2. `docker compose pull && docker compose up -d`.
3. If migrations need rolling back, do so explicitly via `db:rollback` — keep migrations small and reversible.

### Compatibility contract

- Image keeps the same `ENTRYPOINT`, port (3000), env-var contract, and volume paths as the official `chatwoot/chatwoot` image.
- Swap is intended to be a tag change, no compose restructure required.

---

## Sequencing

Suggested order of execution (each is its own PR):

1. **Local dev verification + `.env` scaffold** (no code change, just `.env` template & docs).
2. **CI/CD workflow + branch rename** (`publish_appy_docker.yml`, disable upstream workflows, `master`→`main`). This unblocks everything downstream — we can build images before we make code changes.
3. **Paid unlock + UI scrub** (`APPY_INSTALLATION` flag, plan env vars, hide upgrade UI).
4. **Branding** (`INSTALLATION_NAME`, audit + composable swap, `public/brand/` slot).
5. **Help center admin search** (frontend-only change).
6. **Captain multi-provider** (migration + service change + form update). Last because it's the most code.

Each step is independently shippable; a release tag can be cut after any of them.

---

## Non-goals

- Replacing or extending the AI ops surfacing (copilot, scenarios) beyond the provider switch.
- Replacing chatwoot's billing/Stripe code.
- Auto-deploy to the VPS.
- Mobile app branding (out of scope for this fork).
- Custom domain / SSL automation on the VPS (already handled by existing reverse proxy).

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Upstream merge conflicts grow over time | Keep `APPY_INSTALLATION` and `public/brand/` patterns; minimise touched files; `develop` branch for upstream sync. |
| Captain provider switch breaks existing assistants | NULL provider/model = current OpenAI behaviour; migration is additive. |
| VPS pulls wrong image during cutover | Pin to `vX.Y.Z`, never `latest`, in `docker-compose.production.yaml`. |
| Plan flag flip exposes incomplete EE features | Verify each EE feature manually post-flag-flip in local docker dev before first prod release. |
| GHCR PAT leak | Fine-grained PAT scoped to a single package + read-only; rotate periodically. |
