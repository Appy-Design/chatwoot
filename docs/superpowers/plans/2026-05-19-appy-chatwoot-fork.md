# Appy Support — Chatwoot Fork Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert `Appy-Design/chatwoot` into "Appy Support" — a privately-built, GHCR-published Chatwoot variant with branding swap, Captain AI multi-provider support (OpenAI + Anthropic), all "paid" feature gates removed, and a help-center admin article search bar.

**Architecture:** Six independently-shippable PR groups. Local development via the existing `docker-compose.yaml` (volume-mounted code). Production via a new GHCR workflow producing semver-tagged images that the operator pulls manually onto an IONOS VPS. All changes minimise diff against upstream so we can keep syncing Chatwoot fixes via the kept-as-is `develop` branch.

**Tech Stack:** Ruby 3.4.4 / Rails, Vue 3 + Vite, Postgres 16 (pgvector), Redis, Sidekiq, RubyLLM gem (Anthropic + OpenAI), Docker + docker-compose, GitHub Actions, GitHub Container Registry.

**Spec reference:** `docs/superpowers/specs/2026-05-19-appy-chatwoot-fork-design.md`.

**Conventions used by this plan:**

- Per project `CLAUDE.md`: no new specs are written unless a task explicitly creates one. Verification is manual or via existing specs.
- All Rails commands run inside the dev container: `docker compose exec rails <cmd>`.
- All `git` commands run on the host (outside containers).
- Each PR group ends with a single commit on a feature branch and a PR into `main`.
- Branch naming: `appy/<short-topic>` (e.g. `appy/local-dev`, `appy/ci-ghcr`).

---

## PR 1 — Local Dev Setup (Docker Compose, volume-mounted)

**Goal:** A working dev environment where editing local files live-reloads inside containers. No code changes to the app; only `.env` scaffolding and docs.

**Branch:** `appy/local-dev`

### Task 1.1: Generate `.env` for local development

**Files:**
- Create: `/Users/luke/PhpstormProjects/chatwoot/.env`

- [ ] **Step 1: Generate the secret values**

Run on the host (outside container):

```sh
cd /Users/luke/PhpstormProjects/chatwoot
SECRET_KEY_BASE=$(openssl rand -hex 64)
REDIS_PASSWORD=$(openssl rand -hex 16)
echo "SECRET_KEY_BASE=$SECRET_KEY_BASE"
echo "REDIS_PASSWORD=$REDIS_PASSWORD"
```

Save the printed values — they go into `.env` in the next step.

- [ ] **Step 2: Create `.env`**

Write `/Users/luke/PhpstormProjects/chatwoot/.env`:

```env
# ----- Core -----
SECRET_KEY_BASE=<paste from step 1>
INSTALLATION_NAME=Appy Support
FRONTEND_URL=http://localhost:3000
DEFAULT_LOCALE=en
FORCE_SSL=false
ENABLE_ACCOUNT_SIGNUP=true
RAILS_ENV=development
NODE_ENV=development
APPY_INSTALLATION=true

# ----- Pricing / plan unlock -----
INSTALLATION_PRICING_PLAN=enterprise
INSTALLATION_PRICING_PLAN_QUANTITY=1000

# ----- Postgres (matches docker-compose.yaml) -----
POSTGRES_HOST=postgres
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=
POSTGRES_DATABASE=chatwoot
RAILS_MAX_THREADS=5

# ----- Redis (matches docker-compose.yaml) -----
REDIS_URL=redis://redis:6379
REDIS_PASSWORD=<paste from step 1>

# ----- Mail (dev = Mailhog) -----
MAILER_SENDER_EMAIL=appy@example.com
SMTP_DOMAIN=example.com
SMTP_ADDRESS=mailhog
SMTP_PORT=1025
SMTP_AUTHENTICATION=
SMTP_ENABLE_STARTTLS_AUTO=false

# ----- Active Record Encryption (filled in Task 1.3) -----
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=
```

- [ ] **Step 3: Confirm `.env` is gitignored**

Run:
```sh
git -C /Users/luke/PhpstormProjects/chatwoot check-ignore .env
```
Expected: prints `.env`. If it doesn't, add `.env` to `.gitignore` (it should already be there).

### Task 1.2: First container bring-up + dependency install

**Files:** None modified. Volumes will be populated.

- [ ] **Step 1: Build images and start services**

```sh
cd /Users/luke/PhpstormProjects/chatwoot
docker compose build
docker compose up -d postgres redis mailhog
```

Expected: three containers running. Verify with `docker compose ps`.

- [ ] **Step 2: Install Ruby gems inside the rails container**

```sh
docker compose run --rm rails bundle install
```

Expected: gems install successfully (may take 3–5 minutes the first time). Gems persist in the `bundle` named volume.

- [ ] **Step 3: Install JS deps inside the vite container**

```sh
docker compose run --rm vite pnpm install
```

Expected: `pnpm install` completes. `node_modules` persists in the `node_modules` named volume.

### Task 1.3: Generate Active Record encryption keys + run DB setup

**Files:**
- Modify: `/Users/luke/PhpstormProjects/chatwoot/.env`

- [ ] **Step 1: Generate encryption keys**

```sh
docker compose run --rm rails bundle exec rails db:encryption:init
```

Expected: prints three values (`primary_key`, `deterministic_key`, `key_derivation_salt`).

- [ ] **Step 2: Paste those values into `.env`**

Replace the three empty entries at the bottom of `.env`:
```
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=<value from step 1>
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=<value from step 1>
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=<value from step 1>
```

- [ ] **Step 3: Create DB and run migrations**

```sh
docker compose run --rm rails bundle exec rails db:create db:migrate
```

Expected: database `chatwoot` created and migrations run cleanly.

- [ ] **Step 4: Seed minimal data**

```sh
docker compose run --rm rails bundle exec rails db:seed
```

Expected: super admin user created (`john@acme.inc` / `Password1!` per the seed file — verify in `db/seeds.rb` if changed upstream).

### Task 1.4: Bring up the full stack and verify

**Files:** None.

- [ ] **Step 1: Start all services**

```sh
docker compose up -d
docker compose logs -f rails vite
```

Expected: `rails` logs show "Listening on http://0.0.0.0:3000"; `vite` logs show "ready in Xms" with `http://0.0.0.0:3036`.

- [ ] **Step 2: Open the app**

In a browser, open `http://localhost:3000`. Expected: Chatwoot login page renders. Header text reads "Appy Support" (because `INSTALLATION_NAME` is already plumbed through `useBranding`).

- [ ] **Step 3: Open Mailhog**

In a browser, open `http://localhost:8025`. Expected: Mailhog UI loads (will be empty until the app sends mail).

- [ ] **Step 4: Edit a file, confirm hot reload**

Edit `app/javascript/dashboard/i18n/locale/en/loginPage.json` — change `"WELCOME_BACK": "Welcome Back!"` to `"WELCOME_BACK": "Welcome Back to Appy Support!"`. Save. Reload the browser. Expected: new title appears.

Revert the change before committing.

### Task 1.5: Document local dev in AGENTS.md

**Files:**
- Modify: `/Users/luke/PhpstormProjects/chatwoot/AGENTS.md`

- [ ] **Step 1: Append a "Local Dev — Docker" section**

Append to `AGENTS.md` (do not replace existing content):

```markdown
## Local Dev — Docker (Appy fork)

The fork is developed in Docker via the existing `docker-compose.yaml` (volume-mounts the working copy at `./:/app:delegated`).

**One-time setup:**
1. Copy `.env.example` to `.env` and fill in:
   - `SECRET_KEY_BASE` (`openssl rand -hex 64`)
   - `REDIS_PASSWORD` (any value)
   - `INSTALLATION_NAME=Appy Support`
   - `INSTALLATION_PRICING_PLAN=enterprise`
   - `INSTALLATION_PRICING_PLAN_QUANTITY=1000`
   - `APPY_INSTALLATION=true`
2. `docker compose run --rm rails bundle install`
3. `docker compose run --rm vite pnpm install`
4. `docker compose run --rm rails bundle exec rails db:encryption:init` — paste the three keys into `.env`.
5. `docker compose run --rm rails bundle exec rails db:create db:migrate db:seed`

**Daily:**
```sh
docker compose up           # foreground
docker compose up -d        # background
docker compose logs -f rails vite
docker compose down         # stop all
```

App: `http://localhost:3000` · Mailhog: `http://localhost:8025` · Vite: `http://localhost:3036`.

**Rails CLI:** `docker compose exec rails bundle exec rails <cmd>` (use `exec` for running containers, `run --rm` for one-shots).
```

### Task 1.6: Commit + open PR

- [ ] **Step 1: Create the branch and commit**

```sh
cd /Users/luke/PhpstormProjects/chatwoot
git checkout -b appy/local-dev
git add AGENTS.md docs/superpowers/specs/ docs/superpowers/plans/
git commit -m "docs(appy): add fork spec, implementation plan, and docker dev docs"
```

- [ ] **Step 2: Push and open PR**

```sh
git push -u origin appy/local-dev
gh pr create --base master --title "docs(appy): fork spec + plan + docker dev docs" --body "$(cat <<'EOF'
First PR of the Appy fork work. No code changes — just the design spec, implementation plan, and local-dev docs.

## Summary
- Design spec in `docs/superpowers/specs/`
- Implementation plan in `docs/superpowers/plans/`
- Local Docker dev section appended to `AGENTS.md`

## How to test
- Read the spec; confirm the scope matches what we agreed.
- Follow the AGENTS.md "Local Dev — Docker" section to bring up the stack — `http://localhost:3000` should serve the login page.
EOF
)"
```

Note: PR targets `master` until Task 2.4 renames it to `main`.

---

## PR 2 — CI/CD Workflow + Branch Rename

**Goal:** GHCR multi-arch image builds on PRs (`pr-<number>`) and on `v*` tag pushes (`vX.Y.Z` + `latest`). Disable upstream workflows. Rename `master` → `main`.

**Branch:** `appy/ci-ghcr`

### Task 2.1: Disable upstream FOSS + EE docker workflows

**Files:**
- Modify: `/Users/luke/PhpstormProjects/chatwoot/.github/workflows/publish_foss_docker.yml`
- Modify: `/Users/luke/PhpstormProjects/chatwoot/.github/workflows/publish_ee_docker.yml`

- [ ] **Step 1: Add `if: false` job guard to both workflows**

In `publish_foss_docker.yml`, find the `jobs:` section and add `if: ${{ false }}` to each job:

```yaml
jobs:
  build:
    if: ${{ false }}      # disabled in Appy fork — superseded by publish_appy_docker.yml
    strategy:
      ...
  merge:
    if: ${{ false }}      # disabled in Appy fork
    runs-on: ubuntu-latest
    ...
```

Repeat the same `if: ${{ false }}` addition in `publish_ee_docker.yml`.

- [ ] **Step 2: Visually verify the guard is at job-level, not step-level**

Open both files; confirm the `if: ${{ false }}` is the **first** key under each job key (`build:` and `merge:`), at the same indentation as `strategy:` / `runs-on:`.

### Task 2.2: Add the new GHCR workflow

**Files:**
- Create: `/Users/luke/PhpstormProjects/chatwoot/.github/workflows/publish_appy_docker.yml`

- [ ] **Step 1: Write the workflow**

Create `/Users/luke/PhpstormProjects/chatwoot/.github/workflows/publish_appy_docker.yml`:

```yaml
name: Publish Appy Support docker images

on:
  pull_request:
    branches:
      - main
      - develop
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      tag:
        description: 'Image tag to publish (e.g. v1.2.3 or custom)'
        required: true

env:
  DOCKER_REPO: ghcr.io/appy-design/chatwoot

permissions:
  contents: read
  packages: write

jobs:
  build:
    strategy:
      fail-fast: false
      matrix:
        include:
          - platform: linux/amd64
            runner: ubuntu-latest
          - platform: linux/arm64
            runner: ubuntu-22.04-arm
    runs-on: ${{ matrix.runner }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Prepare platform pair
        run: |
          platform=${{ matrix.platform }}
          echo "PLATFORM_PAIR=${platform//\//-}" >> $GITHUB_ENV

      - name: Set Chatwoot edition (EE retained)
        run: |
          echo -en '\nENV CW_EDITION="ee"' >> docker/Dockerfile

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push by digest
        id: build
        uses: docker/build-push-action@v6
        with:
          context: .
          file: docker/Dockerfile
          platforms: ${{ matrix.platform }}
          push: true
          outputs: type=image,name=${{ env.DOCKER_REPO }},push-by-digest=true,name-canonical=true,push=true

      - name: Export digest
        run: |
          mkdir -p ${{ runner.temp }}/digests
          digest="${{ steps.build.outputs.digest }}"
          touch "${{ runner.temp }}/digests/${digest#sha256:}"

      - name: Upload digest
        uses: actions/upload-artifact@v4
        with:
          name: digests-${{ env.PLATFORM_PAIR }}
          path: ${{ runner.temp }}/digests/*
          if-no-files-found: error
          retention-days: 1

  merge:
    runs-on: ubuntu-latest
    needs:
      - build
    steps:
      - name: Download digests
        uses: actions/download-artifact@v4
        with:
          path: ${{ runner.temp }}/digests
          pattern: digests-*
          merge-multiple: true

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Compute tags
        id: tags
        run: |
          TAGS=()
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            TAGS+=("${DOCKER_REPO}:pr-${{ github.event.number }}")
          elif [ "${{ github.event_name }}" = "push" ]; then
            REF="${{ github.ref_name }}"
            TAGS+=("${DOCKER_REPO}:${REF}")
            TAGS+=("${DOCKER_REPO}:latest")
          elif [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            TAGS+=("${DOCKER_REPO}:${{ inputs.tag }}")
          fi
          echo "tags=${TAGS[*]}" >> $GITHUB_OUTPUT

      - name: Create manifest list and push
        working-directory: ${{ runner.temp }}/digests
        run: |
          TAG_ARGS=""
          for tag in ${{ steps.tags.outputs.tags }}; do
            TAG_ARGS="$TAG_ARGS -t $tag"
          done
          docker buildx imagetools create $TAG_ARGS \
            $(printf '${{ env.DOCKER_REPO }}@sha256:%s ' *)

      - name: Inspect first tag
        run: |
          FIRST_TAG=$(echo "${{ steps.tags.outputs.tags }}" | awk '{print $1}')
          docker buildx imagetools inspect "$FIRST_TAG"
```

- [ ] **Step 2: Verify the workflow YAML is valid**

If `actionlint` is available locally:
```sh
actionlint .github/workflows/publish_appy_docker.yml
```
Otherwise, just visually scan for indentation. The GitHub Actions UI will validate on push.

### Task 2.3: Test the workflow via `workflow_dispatch` (dry run)

**Files:** None modified.

- [ ] **Step 1: Commit and push the branch**

```sh
cd /Users/luke/PhpstormProjects/chatwoot
git checkout -b appy/ci-ghcr
git add .github/workflows/publish_appy_docker.yml .github/workflows/publish_foss_docker.yml .github/workflows/publish_ee_docker.yml
git commit -m "ci(appy): add GHCR publish workflow; disable upstream dockerhub workflows"
git push -u origin appy/ci-ghcr
```

- [ ] **Step 2: Trigger a manual run**

```sh
gh workflow run "Publish Appy Support docker images" --ref appy/ci-ghcr -f tag=test-build
gh run watch
```

Expected: workflow runs to completion. The image `ghcr.io/appy-design/chatwoot:test-build` is published. Verify via:

```sh
gh api /orgs/Appy-Design/packages/container/chatwoot/versions --jq '.[0:5][] | {id, name, tags: .metadata.container.tags}'
```

(Or look in GitHub UI → Organization → Packages.)

- [ ] **Step 3: Delete the test-build tag from GHCR**

In GitHub UI, navigate to the package → versions → delete the `test-build` tag (keeps the registry tidy).

### Task 2.4: Rename `master` → `main` on GitHub

**Files:** None (operates on the remote).

- [ ] **Step 1: Open the PR for the CI workflow before renaming**

```sh
gh pr create --base master --title "ci(appy): GHCR publish workflow + disable upstream workflows" --body "$(cat <<'EOF'
## Summary
- New `publish_appy_docker.yml` builds `ghcr.io/appy-design/chatwoot` multi-arch on PRs and on `v*` tag pushes.
- Existing `publish_foss_docker.yml` and `publish_ee_docker.yml` disabled with `if: ${{ false }}` (file kept intact to avoid upstream-sync conflicts).
- Verified via `workflow_dispatch` test build.

## How to test
- Once merged, opening a PR against `main` should publish `ghcr.io/appy-design/chatwoot:pr-<number>`.
- Pushing a tag `vX.Y.Z` should publish `vX.Y.Z` + `latest`.
EOF
)"
```

- [ ] **Step 2: Merge the PR**

After review, merge via the GitHub UI. Then locally:

```sh
git checkout master
git pull
```

- [ ] **Step 3: Rename the default branch**

```sh
gh api -X POST /repos/Appy-Design/chatwoot/branches/master/rename -f new_name=main
```

GitHub auto-redirects old references. Local:

```sh
git branch -m master main
git fetch origin
git branch -u origin/main main
git remote set-head origin -a
```

- [ ] **Step 4: Verify the default branch**

```sh
gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'
```

Expected: `main`.

- [ ] **Step 5: Verify the previous PR1 docs branch retargets cleanly**

If PR 1 from the previous group is still open, edit it to retarget `main`:
```sh
gh pr edit <PR1_NUMBER> --base main
```

---

## PR 3 — Paid Feature Unlock + UI Scrub

**Goal:** Set the pricing plan to `enterprise` for unlocked features. Hide upgrade-prompt UI surfaces. Gate the scrubs behind a single `APPY_INSTALLATION` env so it's reversible.

**Branch:** `appy/unlock-paid`

### Task 3.1: Set `INSTALLATION_PRICING_PLAN` default in installation_config.yml

**Files:**
- Modify: `/Users/luke/PhpstormProjects/chatwoot/config/installation_config.yml:277-282`

- [ ] **Step 1: Change defaults**

In `config/installation_config.yml`, find lines around 277:

```yaml
- name: INSTALLATION_PRICING_PLAN
  value: 'community'
  description: 'The pricing plan for the installation, retrieved from the billing API'
- name: INSTALLATION_PRICING_PLAN_QUANTITY
  value: 0
```

Change to:

```yaml
- name: INSTALLATION_PRICING_PLAN
  value: 'enterprise'
  description: 'The pricing plan for the installation. Set to "enterprise" in Appy fork to unlock plan-gated features.'
- name: INSTALLATION_PRICING_PLAN_QUANTITY
  value: 1000
```

- [ ] **Step 2: Reset the config for an existing dev DB**

If the dev DB already has the old `community` value persisted, reload installation configs:

```sh
docker compose exec rails bundle exec rails runner "InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN')&.update(value: 'enterprise'); InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY')&.update(value: 1000)"
```

Expected: command completes silently.

- [ ] **Step 3: Verify the plan flag is in effect**

```sh
docker compose exec rails bundle exec rails runner "puts ChatwootHub.pricing_plan"
```

Expected: `enterprise`.

### Task 3.2: Add `APPY_INSTALLATION` gating helper

**Files:**
- Create: `/Users/luke/PhpstormProjects/chatwoot/app/helpers/appy_installation_helper.rb`

- [ ] **Step 1: Write the helper**

Create `/Users/luke/PhpstormProjects/chatwoot/app/helpers/appy_installation_helper.rb`:

```ruby
module AppyInstallationHelper
  def appy_installation?
    ENV['APPY_INSTALLATION'].to_s == 'true'
  end
  module_function :appy_installation?
end
```

- [ ] **Step 2: Verify it loads**

```sh
docker compose exec rails bundle exec rails runner "puts AppyInstallationHelper.appy_installation?"
```

Expected: `true` (because `APPY_INSTALLATION=true` is in `.env`).

### Task 3.3: Hide the super-admin upgrade button

**Files:**
- Modify: `/Users/luke/PhpstormProjects/chatwoot/app/views/super_admin/settings/_upgrade_button_enterprise.html.erb`

- [ ] **Step 1: Wrap the existing markup in an `unless` guard**

Open the file. Wrap the entire `<a ...>...</a>` block:

```erb
<% unless AppyInstallationHelper.appy_installation? %>
  <a href="<%= ChatwootHub.billing_url %>" ... >
    ... existing content ...
  </a>
<% end %>
```

(Preserve the existing HTML content inside; only add the outer `<% unless %>` / `<% end %>`.)

- [ ] **Step 2: Reload the super admin settings page**

In a browser, navigate to `http://localhost:3000/super_admin/settings`. Expected: the "Upgrade" button no longer renders. (Sign in with the seeded admin if needed.)

### Task 3.4: Expose `appyInstallation` to the Vue dashboard

**Files:**
- Modify: `/Users/luke/PhpstormProjects/chatwoot/app/controllers/dashboard_controller.rb`
- Modify: `/Users/luke/PhpstormProjects/chatwoot/app/javascript/dashboard/store/modules/globalConfig.js` (if it exists; verify path first via `grep -rln "appConfig\|globalConfig" app/javascript/dashboard/store/modules | head`)

- [ ] **Step 1: Add `appy_installation` flag to dashboard global config**

Open `app/controllers/dashboard_controller.rb`. Find the `set_global_config` or equivalent method that serialises the global config payload (search for `globalConfig` JSON construction). Add:

```ruby
@global_config[:appy_installation] = ENV['APPY_INSTALLATION'].to_s == 'true'
```

If the global config is built by a presenter or serializer instead (e.g., `app/views/dashboard/_globals.html.erb`), add the same field there as `appyInstallation: <%= ENV['APPY_INSTALLATION'].to_s == 'true' %>`.

- [ ] **Step 2: Verify the flag reaches the frontend**

Open `http://localhost:3000` in browser. Open DevTools console:

```js
window.globalConfig?.appyInstallation
```

Expected: `true`.

### Task 3.5: Hide the help-center `UpgradePage`

**Files:**
- Modify: `/Users/luke/PhpstormProjects/chatwoot/app/javascript/dashboard/routes/dashboard/helpcenter/pages/HelpCenterPageRouteView.vue:5,74`

- [ ] **Step 1: Inspect the existing render gate**

Read `HelpCenterPageRouteView.vue` lines 1–80. The component currently renders `<UpgradePage v-else />` when help-center features aren't available. With `INSTALLATION_PRICING_PLAN=enterprise` set in Task 3.1, the upstream gate already evaluates to "features available", so the upgrade page won't render in practice. We add belt-and-suspenders here.

- [ ] **Step 2: Force the upgrade branch off in Appy installs**

Modify line 74 (`<UpgradePage v-else />`) to:

```vue
<UpgradePage v-else-if="!appyInstallation" />
```

Add to the `<script setup>` block:

```js
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store.js';
const globalConfig = useMapGetter('globalConfig/get');
const appyInstallation = computed(() => !!globalConfig.value?.appyInstallation);
```

(If the component uses Options API, expose `appyInstallation` via `computed` instead, but per `CLAUDE.md` the project standard is `<script setup>`. Keep style consistent.)

- [ ] **Step 3: Verify**

Navigate to `http://localhost:3000` → Help Center. Expected: help-center loads normally (portals UI, not the upgrade page).

### Task 3.6: Audit other upgrade CTAs

**Files:** Various — discovered via grep.

- [ ] **Step 1: Find all upgrade CTAs**

```sh
cd /Users/luke/PhpstormProjects/chatwoot
grep -rln "UpgradePage\|UPGRADE_NOW\|UPGRADE_PLAN\|upgrade-button\|isOnTrialPlan\|isFeaturePremium" app/javascript app/views --include='*.vue' --include='*.js' --include='*.erb' | grep -v spec | grep -v __tests__
```

- [ ] **Step 2: For each customer-facing hit, gate on `appyInstallation`**

For each file the grep finds in **customer-facing** code paths (portal, widget, help-center, agent settings shown daily), wrap the upgrade prompt in `v-if="!appyInstallation"`. Examples:

- "Upgrade" CTA buttons in agent settings panes
- "Premium feature" badges
- Trial expiry banners

Skip:
- super-admin pages (handled in Task 3.3)
- internal billing/Stripe code paths (left intact per spec)

- [ ] **Step 3: Manually click through all settings**

In the dashboard, visit every top-level settings tab: Agents, Teams, Inboxes, Labels, Custom Attributes, Automation, Macros, Integrations, SLA, Audit Logs, Reports. Expected: no upgrade prompts anywhere.

### Task 3.7: Commit + PR

- [ ] **Step 1: Commit**

```sh
git add config/installation_config.yml \
  app/helpers/appy_installation_helper.rb \
  app/views/super_admin/settings/_upgrade_button_enterprise.html.erb \
  app/controllers/dashboard_controller.rb \
  app/javascript/dashboard/routes/dashboard/helpcenter/pages/HelpCenterPageRouteView.vue
# add any other files modified during Task 3.6
git commit -m "feat(appy): unlock plan-gated features + hide upgrade UI

Set INSTALLATION_PRICING_PLAN default to 'enterprise'. Add
APPY_INSTALLATION env-gated helper and hide upgrade prompts on
the help center and super admin pages."
```

- [ ] **Step 2: Push and open PR**

```sh
git push -u origin appy/unlock-paid
gh pr create --base main --title "feat(appy): unlock plan-gated features + scrub upgrade UI" --body "$(cat <<'EOF'
## Summary
- Default `INSTALLATION_PRICING_PLAN` to `enterprise` (was `community`) so EE features light up.
- Add `APPY_INSTALLATION` env flag + helper.
- Hide super-admin upgrade button, help-center `UpgradePage`, and other customer-facing upgrade CTAs when `APPY_INSTALLATION=true`.

## How to test
- Set `APPY_INSTALLATION=true` and `INSTALLATION_PRICING_PLAN=enterprise` in `.env`.
- Restart `docker compose` and visit `/super_admin/settings` — upgrade button gone.
- Visit `/app/.../helpcenter` — no upgrade prompt; portal UI renders.
- Visit each settings tab — no upgrade CTAs.

## What changed
- `config/installation_config.yml` default plan
- New `app/helpers/appy_installation_helper.rb`
- `_upgrade_button_enterprise.html.erb`, `HelpCenterPageRouteView.vue`, and any other CTA gates found by grep audit.
EOF
)"
```

---

## PR 4 — Branding (customer-facing surfaces)

**Goal:** Replace "Chatwoot" with the configured `installation_name` ("Appy Support") across the help center portal, widget, survey, and email templates. Introduce a backend branding helper for ERB. Add a `public/brand-assets/` swap path (assets already live there).

**Branch:** `appy/branding`

### Task 4.1: Add a backend branding helper

**Files:**
- Create: `/Users/luke/PhpstormProjects/chatwoot/app/services/branding/installation_name_service.rb`

- [ ] **Step 1: Write the service**

Create `/Users/luke/PhpstormProjects/chatwoot/app/services/branding/installation_name_service.rb`:

```ruby
# frozen_string_literal: true

# Backend counterpart to the JS `useBranding.replaceInstallationName` composable.
# Swaps the literal word "Chatwoot" with the configured installation name.
module Branding
  module InstallationNameService
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
end
```

- [ ] **Step 2: Wire it into ApplicationHelper as a view helper**

Modify `app/helpers/application_helper.rb` — append:

```ruby
def installation_name
  Branding::InstallationNameService.installation_name
end

def with_installation_name(text)
  Branding::InstallationNameService.replace(text)
end
```

- [ ] **Step 3: Smoke-test the helper**

```sh
docker compose exec rails bundle exec rails runner "puts Branding::InstallationNameService.replace('Welcome to Chatwoot!')"
```

Expected: `Welcome to Appy Support!`

### Task 4.2: Audit + replace "Chatwoot" in email templates

**Files:** discovered via grep.

- [ ] **Step 1: Find hardcoded "Chatwoot" in mailer views**

```sh
cd /Users/luke/PhpstormProjects/chatwoot
grep -rln "Chatwoot" app/views/mailers app/views/devise 2>/dev/null
```

- [ ] **Step 2: For each match, replace with `with_installation_name`**

In `.erb` files, replace literal `Chatwoot` with `<%= installation_name %>` (when it's standalone) or wrap longer strings with `<%= with_installation_name("...") %>`.

Example — in `app/views/mailers/devise_mailer/confirmation_instructions.html.erb`:

Before:
```erb
<p>Welcome to Chatwoot!</p>
```

After:
```erb
<p>Welcome to <%= installation_name %>!</p>
```

For strings containing brand-related URLs (`chatwoot.com`, support links), leave them alone — they're upstream's docs links, not brand mentions. Only replace standalone product-name occurrences.

- [ ] **Step 3: Send a test email and verify**

```sh
docker compose exec rails bundle exec rails runner "DeviseMailer.confirmation_instructions(User.first, 'test-token').deliver_now"
```

Open Mailhog at `http://localhost:8025` — confirm the email body says "Appy Support" wherever "Chatwoot" used to appear.

### Task 4.3: Audit + replace in the help-center portal (`app/javascript/portal/**`)

**Files:** discovered via grep.

- [ ] **Step 1: Find candidates**

```sh
grep -rn ">Chatwoot<\|'Chatwoot'\|\"Chatwoot\"\|Chatwoot is\|by Chatwoot" app/javascript/portal --include='*.vue' --include='*.js'
```

- [ ] **Step 2: Replace in templates using the composable**

For each `.vue` file with the literal "Chatwoot" in the `<template>`, change the binding to use `replaceInstallationName`:

```vue
<script setup>
import { useBranding } from 'shared/composables/useBranding';
const { replaceInstallationName } = useBranding();
</script>

<template>
  <span>{{ replaceInstallationName('Powered by Chatwoot') }}</span>
</template>
```

For i18n strings already containing "Chatwoot", call `replaceInstallationName($t('KEY'))` instead of `$t('KEY')` in the template.

- [ ] **Step 3: Verify in browser**

Visit the public portal (`http://localhost:3000/hc/<portal-slug>` — create a portal in the dashboard if needed via Help Center → New Portal). Expected: "Appy Support" everywhere "Chatwoot" used to appear.

### Task 4.4: Audit + replace in the widget (`app/javascript/widget/**`)

**Files:** discovered via grep.

- [ ] **Step 1: Find candidates**

```sh
grep -rn ">Chatwoot<\|'Chatwoot'\|\"Chatwoot\"\|Chatwoot is\|by Chatwoot" app/javascript/widget --include='*.vue' --include='*.js'
```

- [ ] **Step 2: Replace using the composable** (same pattern as Task 4.3)

- [ ] **Step 3: Verify in browser**

Embed the widget on a test page. The standard test page is `http://localhost:3000/widget_tests` (Rails route). Expected: "Appy Support" branding.

### Task 4.5: Audit + replace in the survey (`app/javascript/survey/**`)

**Files:** discovered via grep.

- [ ] **Step 1: Find candidates**

```sh
grep -rn ">Chatwoot<\|'Chatwoot'\|\"Chatwoot\"\|Chatwoot is\|by Chatwoot" app/javascript/survey --include='*.vue' --include='*.js'
```

- [ ] **Step 2: Replace using the composable** (same pattern as Task 4.3)

- [ ] **Step 3: Verify in browser**

Trigger a CSAT survey: in a closed conversation, "Send CSAT" → click the resulting public URL. Expected: branding shows "Appy Support".

### Task 4.6: Brand-assets swap directory

**Files:** none modified (documentation only); `public/brand-assets/` already exists.

- [ ] **Step 1: Confirm existing layout**

```sh
ls /Users/luke/PhpstormProjects/chatwoot/public/brand-assets/
```

Expected: `logo.svg`, `logo_dark.svg`, `logo_thumbnail.svg` (Chatwoot defaults).

- [ ] **Step 2: Document the override convention**

Append to `AGENTS.md` (the "Local Dev — Docker" section from PR 1):

```markdown
### Logo / favicon override

Customer-facing logos live in `public/brand-assets/`. To swap branding:
- Replace `logo.svg`, `logo_dark.svg`, `logo_thumbnail.svg` with Appy Support equivalents (same filenames, same dimensions).
- For favicons, replace `public/favicon-*.png` and `public/favicon-badge-*.png`.

Once committed, the next built image picks them up — no code change required.
```

### Task 4.7: Commit + PR

- [ ] **Step 1: Commit**

```sh
git checkout -b appy/branding
git add app/services/branding \
  app/helpers/application_helper.rb \
  app/views/mailers \
  app/javascript/portal \
  app/javascript/widget \
  app/javascript/survey \
  AGENTS.md
git commit -m "feat(appy): brand customer-facing surfaces with INSTALLATION_NAME

Add Branding::InstallationNameService for ERB. Replace literal
'Chatwoot' with installation-name composable usage across portal,
widget, survey, and email templates. Document logo-swap convention."
```

- [ ] **Step 2: Push and open PR**

```sh
git push -u origin appy/branding
gh pr create --base main --title "feat(appy): brand customer-facing surfaces with installation name" --body "$(cat <<'EOF'
## Summary
- Backend `Branding::InstallationNameService` + `installation_name` view helper for ERB.
- Replaced hardcoded "Chatwoot" with composable calls in portal, widget, survey, and mailer templates.
- Documented `public/brand-assets/` swap convention so logos can be dropped in later.

## How to test
- Set `INSTALLATION_NAME=Appy Support` in `.env`.
- Visit a help center portal, the widget test page, a CSAT survey URL — all should say "Appy Support".
- Trigger a confirmation email and open Mailhog — body should say "Appy Support".
EOF
)"
```

---

## PR 5 — Help Center Admin Article Search

**Goal:** Add a debounced title-only search input above the article list in `PortalsArticlesIndexPage.vue`. Scope: current portal + locale + status tab. In-memory state (no URL persistence).

**Branch:** `appy/helpcenter-search`

### Task 5.1: Confirm the API supports a title search parameter

**Files:** none modified.

- [ ] **Step 1: Inspect the existing articles API client**

Read `app/javascript/dashboard/api/helpCenter/articles.js`. Confirm the `search` (or `fetch`) method accepts a `query` parameter and passes it to the backend.

- [ ] **Step 2: Inspect the backend articles index controller**

Find via:
```sh
grep -rln "class.*ArticlesController" app/controllers
```

Read the matching controller. Confirm the `index` action accepts `params[:query]` (or `params[:q]`) and filters by `Article.where('title ILIKE ?', "%#{query}%")` or similar.

If the backend doesn't support a title-only search, fall back to using the existing `search` endpoint that powers the editor's `SearchPopover`. If neither exists, add a `query` param to the index controller's filter chain (~5 lines).

### Task 5.2: Add the search input to `PortalsArticlesIndexPage.vue`

**Files:**
- Modify: `/Users/luke/PhpstormProjects/chatwoot/app/javascript/dashboard/routes/dashboard/helpcenter/pages/PortalsArticlesIndexPage.vue`

- [ ] **Step 1: Add search input above the article list**

Open `PortalsArticlesIndexPage.vue`. Find the top of the list area (above the article table / `ArticleList` component). Add a search input row:

```vue
<template>
  <!-- existing header bits -->
  <div class="px-4 pt-4">
    <input
      v-model="searchQuery"
      type="search"
      :placeholder="$t('HELP_CENTER.SEARCH_ARTICLES.PLACEHOLDER')"
      class="w-full max-w-md rounded border border-n-slate-5 bg-n-alpha-1 px-3 py-2 text-sm text-n-slate-12 placeholder-n-slate-9 focus:border-n-brand focus:outline-none"
    />
  </div>
  <!-- existing <ArticleList :articles="filteredArticles" ... /> -->
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import { debounce } from '@chatwoot/utils';

// ... existing imports + setup ...

const searchQuery = ref('');
const debouncedQuery = ref('');

const updateDebounced = debounce((val) => {
  debouncedQuery.value = val;
}, 300);

watch(searchQuery, (val) => updateDebounced(val));

// Pass debouncedQuery into the existing articles fetch.
// If the page uses a store action `articles/fetch`, change it to pass `query: debouncedQuery.value`.
// If it uses a local computed over `state.articles`, filter client-side as a fallback:
const filteredArticles = computed(() => {
  if (!debouncedQuery.value) return articles.value;
  const q = debouncedQuery.value.toLowerCase();
  return articles.value.filter(a => a.title?.toLowerCase().includes(q));
});
</script>
```

Choose **one** of the two integration paths:

- **Path A (preferred): server-side filtering** — call the existing fetch action with the `query` param when `debouncedQuery` changes:
  ```js
  watch(debouncedQuery, (q) => {
    store.dispatch('articles/fetch', { portalSlug, locale, status, query: q });
  });
  ```
  Use the API method confirmed in Task 5.1. Replace `<ArticleList :articles="articles">` (no change needed; the store's `articles` state holds the filtered results).

- **Path B (fallback): client-side filtering** — keep the `filteredArticles` computed and use it as the list source. Only do this if Task 5.1 found the backend doesn't easily support `query`.

- [ ] **Step 2: Add the i18n key**

Open `app/javascript/dashboard/i18n/locale/en/helpCenter.json`. Find the `"HELP_CENTER"` object. Add:

```json
"SEARCH_ARTICLES": {
  "PLACEHOLDER": "Search articles by title…",
  "NO_RESULTS": "No articles match this search."
}
```

(Per `CLAUDE.md`, only update `en.json` — other locales are community-translated.)

- [ ] **Step 3: Verify**

In browser, navigate to `Help Center → Portal → Articles`. Expected: search input above the list. Type a partial title. After ~300ms, the list filters. Clear the input, full list returns.

### Task 5.3: Empty state for "no matches"

**Files:**
- Modify: `/Users/luke/PhpstormProjects/chatwoot/app/javascript/dashboard/routes/dashboard/helpcenter/pages/PortalsArticlesIndexPage.vue`

- [ ] **Step 1: Add a no-results message**

In the template, after `<ArticleList>` (or wherever the list renders), add:

```vue
<div
  v-if="debouncedQuery && filteredArticles.length === 0"
  class="px-4 py-8 text-center text-n-slate-10"
>
  {{ $t('HELP_CENTER.SEARCH_ARTICLES.NO_RESULTS') }}
</div>
```

(If using server-side filtering — Path A — read the page's existing empty state and adapt the message to show only when `searchQuery` is non-empty AND results are empty.)

- [ ] **Step 2: Verify**

Type a string no article matches. Expected: "No articles match this search." displays.

### Task 5.4: Commit + PR

- [ ] **Step 1: Commit**

```sh
git checkout -b appy/helpcenter-search
git add app/javascript/dashboard/routes/dashboard/helpcenter/pages/PortalsArticlesIndexPage.vue \
       app/javascript/dashboard/i18n/locale/en/helpCenter.json
# If backend controller needed a query param, also:
# git add app/controllers/api/v2/accounts/articles_controller.rb
git commit -m "feat(appy): add title search to help center admin article list"
```

- [ ] **Step 2: Push and open PR**

```sh
git push -u origin appy/helpcenter-search
gh pr create --base main --title "feat(appy): help center admin article search" --body "$(cat <<'EOF'
## Summary
Adds a debounced title-only search input above the article list in the help center admin. Scope: current portal + locale + status tab. In-memory state, clears on refresh.

## How to test
- Open Help Center → Portal → Articles.
- Type a partial article title — list filters live (~300ms debounce).
- Clear the input — full list returns.
- Search for something that won't match — "No articles match this search." displays.
EOF
)"
```

---

## PR 6 — Captain Multi-Provider (OpenAI + Anthropic)

**Goal:** Captain assistants can use either OpenAI or Anthropic Claude as their LLM. Two installation-level config keys per provider (key + model). Per-assistant override via a `provider` + `model` dropdown.

**Branch:** `appy/captain-multi-provider`

### Task 6.1: Add Anthropic config keys to `installation_config.yml`

**Files:**
- Modify: `/Users/luke/PhpstormProjects/chatwoot/config/installation_config.yml`

- [ ] **Step 1: Find the existing `CAPTAIN_OPEN_AI_*` block**

```sh
grep -n "CAPTAIN_OPEN_AI" config/installation_config.yml
```

- [ ] **Step 2: Add Anthropic equivalents immediately after**

After the last `CAPTAIN_OPEN_AI_*` entry, add:

```yaml
- name: CAPTAIN_ANTHROPIC_API_KEY
  value:
  type: secret
  description: 'API key for Anthropic (used when an assistant has provider=anthropic).'
- name: CAPTAIN_ANTHROPIC_MODEL
  value: 'claude-sonnet-4-5'
  description: 'Default Anthropic model for Captain assistants when not overridden.'
```

- [ ] **Step 3: Seed the new keys**

```sh
docker compose exec rails bundle exec rails runner "Installation::ConfigService.new.send(:run_setup)"
```

(Or whatever the existing config-bootstrap entry point is — find via `grep -rn 'installation_config.yml' lib config app`.)

- [ ] **Step 4: Verify in super admin**

Visit `http://localhost:3000/super_admin/app_configs`. Expected: two new fields `CAPTAIN_ANTHROPIC_API_KEY` and `CAPTAIN_ANTHROPIC_MODEL` appear with the defaults.

### Task 6.2: Teach `Llm::Config` about Anthropic

**Files:**
- Modify: `/Users/luke/PhpstormProjects/chatwoot/lib/llm/config.rb`

- [ ] **Step 1: Add Anthropic configuration**

Replace the contents of `configure_ruby_llm` and the supporting helpers with:

```ruby
def configure_ruby_llm
  RubyLLM.configure do |config|
    config.openai_api_key = openai_api_key if openai_api_key.present?
    config.openai_api_base = openai_endpoint.chomp('/') if openai_endpoint.present?
    config.anthropic_api_key = anthropic_api_key if anthropic_api_key.present?
    config.model_registry_file = Rails.root.join('config/llm_models.json').to_s
    config.logger = Rails.logger
  end
end

def openai_api_key
  InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
end

def openai_endpoint
  InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
end

def anthropic_api_key
  InstallationConfig.find_by(name: 'CAPTAIN_ANTHROPIC_API_KEY')&.value
end
```

Keep the existing `system_api_key` alias **only if** it's referenced elsewhere — `grep -rn 'Llm::Config.system_api_key' app enterprise lib`. If unused, delete it. (Don't leave dead aliases.)

- [ ] **Step 2: Smoke test Anthropic config wiring**

In `.env`, set a placeholder `CAPTAIN_ANTHROPIC_API_KEY=test-key` (overrides installation config in dev via `Installation::ConfigService`). Restart `docker compose`.

```sh
docker compose exec rails bundle exec rails runner "Llm::Config.initialize!; puts RubyLLM.config.anthropic_api_key"
```

Expected: `test-key`.

### Task 6.3: Migration — add `provider` + `model` to `captain_assistants`

**Files:**
- Create: `/Users/luke/PhpstormProjects/chatwoot/db/migrate/<timestamp>_add_provider_to_captain_assistants.rb`

- [ ] **Step 1: Generate the migration**

```sh
docker compose exec rails bundle exec rails generate migration AddProviderToCaptainAssistants provider:string model_override:string
```

Note: column name is `model_override` (not `model`) — `model` collides with Rails' `model_name` reflection. We'll expose it as `model` in the API layer.

- [ ] **Step 2: Edit the generated migration**

Open the new file. Ensure both columns are `null: true` (default behaviour for `string` in Rails, but be explicit) and add an index on `provider`:

```ruby
class AddProviderToCaptainAssistants < ActiveRecord::Migration[7.1]
  def change
    add_column :captain_assistants, :provider, :string, null: true
    add_column :captain_assistants, :model_override, :string, null: true
    add_index :captain_assistants, :provider
  end
end
```

- [ ] **Step 3: Run the migration**

```sh
docker compose exec rails bundle exec rails db:migrate
```

Expected: migration runs cleanly.

- [ ] **Step 4: Verify backwards compatibility**

```sh
docker compose exec rails bundle exec rails runner "puts Captain::Assistant.first&.attributes.to_yaml"
```

Expected: existing rows have `provider: nil` and `model_override: nil`. Confirms NULL = "use installation default".

### Task 6.4: Wire provider selection into `Llm::BaseAiService`

**Files:**
- Modify: `/Users/luke/PhpstormProjects/chatwoot/enterprise/app/services/llm/base_ai_service.rb`

- [ ] **Step 1: Refactor to accept an optional assistant**

Open `enterprise/app/services/llm/base_ai_service.rb`. Replace the contents with:

```ruby
# frozen_string_literal: true

# Base service for LLM operations using RubyLLM.
# New features should inherit from this class.
class Llm::BaseAiService
  DEFAULT_TEMPERATURE = 1.0

  attr_reader :model, :temperature, :provider

  def initialize(assistant: nil)
    Llm::Config.initialize!
    @assistant = assistant
    setup_provider_and_model
    setup_temperature
  end

  def chat(model: @model, temperature: @temperature, provider: @provider)
    RubyLLM.chat(model: model, provider: provider).with_temperature(temperature)
  end

  private

  def sanitize_json_response(response)
    return response if response.nil?

    response.strip.sub(/\A```(?:\w*)\s*\n?/, '').sub(/\n?\s*```\s*\z/, '').strip
  end

  def setup_provider_and_model
    @provider = (@assistant&.provider.presence || 'openai').to_sym
    @model = @assistant&.model_override.presence || installation_default_model
  end

  def installation_default_model
    config_key = @provider == :anthropic ? 'CAPTAIN_ANTHROPIC_MODEL' : 'CAPTAIN_OPEN_AI_MODEL'
    InstallationConfig.find_by(name: config_key)&.value.presence || fallback_model
  end

  def fallback_model
    @provider == :anthropic ? 'claude-sonnet-4-5' : Llm::Config::DEFAULT_MODEL
  end

  def setup_temperature
    @temperature = DEFAULT_TEMPERATURE
  end
end
```

- [ ] **Step 2: Find subclasses and update them to pass the assistant**

```sh
grep -rln "Llm::BaseAiService\|< BaseAiService\|class.*<\s*Llm::" enterprise/app/services
```

For each subclass instance that runs in the context of an assistant, change:
- `MyService.new` → `MyService.new(assistant: assistant)` at every call site.

Focus on Captain-related services first (chat completions, response generation). Translation services that don't operate on an assistant can stay parameterless.

- [ ] **Step 3: Smoke-test with a Claude assistant**

In a Rails console:

```sh
docker compose exec rails bundle exec rails console
```

Then:
```ruby
a = Captain::Assistant.first
a.update!(provider: 'anthropic', model_override: 'claude-sonnet-4-5')
service = Llm::BaseAiService.new(assistant: a)
puts service.provider     # => :anthropic
puts service.model        # => "claude-sonnet-4-5"
```

### Task 6.5: Expose `provider` + `model_override` through the API

**Files:**
- Modify: `/Users/luke/PhpstormProjects/chatwoot/enterprise/app/controllers/api/v1/accounts/captain/assistants_controller.rb` (path: find via `grep -rn 'Captain.*Assistants.*Controller' enterprise/app/controllers`)
- Modify: `/Users/luke/PhpstormProjects/chatwoot/enterprise/app/models/captain/assistant.rb`

- [ ] **Step 1: Permit the new params**

In the assistants controller, find the strong params method (usually `assistant_params` or similar). Add `:provider` and `:model_override` to the permitted list.

- [ ] **Step 2: Add a model-level validation**

In `enterprise/app/models/captain/assistant.rb`, add:

```ruby
validates :provider, inclusion: { in: %w[openai anthropic], allow_nil: true }
```

- [ ] **Step 3: Add to the JSON serializer**

Find the assistant serializer (`grep -rn 'class.*Assistant.*Serializer\|jbuilder' enterprise/app | head`). Expose `provider` and `model_override` (alias as `model` in the JSON if the frontend reads `model`).

- [ ] **Step 4: Smoke test the API**

```sh
docker compose exec rails bundle exec rails runner "
a = Captain::Assistant.first
a.update!(provider: 'anthropic', model_override: 'claude-sonnet-4-5')
puts a.reload.attributes.slice('provider', 'model_override').to_yaml
"
```

Expected: prints `provider: anthropic, model_override: claude-sonnet-4-5`.

### Task 6.6: Add provider picker to the assistant edit form

**Files:**
- Modify: the Captain assistant edit form (find via `grep -rln "captain.*assistant.*edit\|AssistantForm\|AssistantConfig" app/javascript/dashboard/components-next/captain`)

- [ ] **Step 1: Locate the form**

```sh
grep -rln "instructions\|response_guidelines" app/javascript/dashboard/components-next/captain/assistant 2>/dev/null
```

Open the file that contains the assistant edit form fields (likely `AssistantConfig.vue` or similar — the file that already binds `name`, `description`, `instructions`, etc.).

- [ ] **Step 2: Add provider dropdown and model field**

Within the form's `<template>`, add (placement: just below the existing model-related field, or near the instructions):

```vue
<div class="flex flex-col gap-2">
  <label class="text-sm font-medium text-n-slate-12">
    {{ $t('CAPTAIN.ASSISTANTS.PROVIDER.LABEL') }}
  </label>
  <select
    v-model="form.provider"
    class="rounded border border-n-slate-5 bg-n-alpha-1 px-3 py-2 text-sm"
  >
    <option :value="null">{{ $t('CAPTAIN.ASSISTANTS.PROVIDER.DEFAULT') }}</option>
    <option value="openai">OpenAI</option>
    <option value="anthropic">Anthropic (Claude)</option>
  </select>
</div>

<div class="flex flex-col gap-2">
  <label class="text-sm font-medium text-n-slate-12">
    {{ $t('CAPTAIN.ASSISTANTS.MODEL.LABEL') }}
  </label>
  <input
    v-model="form.model_override"
    type="text"
    :placeholder="$t('CAPTAIN.ASSISTANTS.MODEL.PLACEHOLDER')"
    class="rounded border border-n-slate-5 bg-n-alpha-1 px-3 py-2 text-sm"
  />
</div>
```

In `<script setup>`, ensure `form.provider` and `form.model_override` are initialised from the assistant payload (`form.provider = assistant.provider || null`).

- [ ] **Step 3: Add the i18n strings**

Open `app/javascript/dashboard/i18n/locale/en/captain.json` (find via `grep -rln 'CAPTAIN' app/javascript/dashboard/i18n/locale/en` if it's elsewhere). Add:

```json
"PROVIDER": {
  "LABEL": "AI provider",
  "DEFAULT": "Use installation default"
},
"MODEL": {
  "LABEL": "Model override",
  "PLACEHOLDER": "Leave blank to use installation default"
}
```

- [ ] **Step 4: Verify end-to-end**

1. In super admin → app configs, fill in `CAPTAIN_ANTHROPIC_API_KEY` with a real Anthropic key.
2. In the dashboard → Captain → Assistants, edit an assistant.
3. Set provider = Anthropic. Save.
4. Trigger an assistant action (e.g. test a response generation) — verify the request goes to Anthropic. Inspect logs:

```sh
docker compose logs rails | grep -i "anthropic\|claude"
```

Expected: requests routed via Anthropic, response returned successfully.

### Task 6.7: Commit + PR

- [ ] **Step 1: Commit**

```sh
git checkout -b appy/captain-multi-provider
git add config/installation_config.yml \
        lib/llm/config.rb \
        db/migrate/*add_provider_to_captain_assistants.rb \
        db/schema.rb \
        enterprise/app/services/llm/base_ai_service.rb \
        enterprise/app/models/captain/assistant.rb
# add controller, serializer, and Vue form files as discovered
git commit -m "feat(captain): support OpenAI and Anthropic providers per assistant

Add CAPTAIN_ANTHROPIC_API_KEY + CAPTAIN_ANTHROPIC_MODEL installation
configs. Add provider + model_override columns to captain_assistants
(NULL = use installation default, backwards-compatible). Llm::BaseAiService
now resolves provider per-assistant. Frontend picker added to the
assistant edit form."
```

- [ ] **Step 2: Push and open PR**

```sh
git push -u origin appy/captain-multi-provider
gh pr create --base main --title "feat(captain): OpenAI + Anthropic per-assistant providers" --body "$(cat <<'EOF'
## Summary
Lets each Captain assistant choose its LLM provider (OpenAI or Anthropic Claude). Provider + optional model override stored per-assistant; NULL falls back to installation default.

## Closes
N/A — internal fork feature.

## How to test
1. Set `CAPTAIN_ANTHROPIC_API_KEY` via super admin → app configs.
2. Edit a Captain assistant → set AI provider to Anthropic, leave model blank.
3. Trigger a Captain response — request goes to Claude; verify via `docker compose logs rails`.
4. Switch the assistant back to OpenAI — requests route to OpenAI.

## What changed
- `config/installation_config.yml` adds Anthropic key + model.
- `lib/llm/config.rb` configures both providers via `RubyLLM.configure`.
- New migration adds `provider` + `model_override` to `captain_assistants` (both nullable, backwards-compatible).
- `Llm::BaseAiService` resolves provider/model per assistant.
- New provider dropdown + model field in the assistant edit form.
EOF
)"
```

---

## After all PRs merged: first production release

- [ ] **Step 1: Tag a release on `main`**

```sh
git checkout main
git pull
git tag -a v1.0.0 -m "v1.0.0 — initial Appy Support fork release"
git push origin v1.0.0
```

Expected: `publish_appy_docker.yml` runs and publishes `ghcr.io/appy-design/chatwoot:v1.0.0` and `:latest`.

- [ ] **Step 2: Cutover on the IONOS VPS**

On the VPS (manual operator action — not automated):

1. Generate a fine-grained GitHub PAT with `read:packages` scope, limited to `Appy-Design/chatwoot`.
2. `echo $PAT | docker login ghcr.io -u <gh-username> --password-stdin`
3. `pg_dump -Fc -f appy-pre-cutover.dump chatwoot` (Postgres backup).
4. Edit `docker-compose.production.yaml`: change `image: chatwoot/chatwoot:latest` → `image: ghcr.io/appy-design/chatwoot:v1.0.0`.
5. `docker compose pull`
6. `docker compose run --rm rails bundle exec rails db:migrate`
7. `docker compose up -d`
8. `curl -fsSL https://<your-domain>/api && echo OK`

**Rollback:** edit `docker-compose.production.yaml` back to `chatwoot/chatwoot:<previous-version>`, `docker compose pull && docker compose up -d`. Restore Postgres from `appy-pre-cutover.dump` only if the migration broke compatibility (unlikely — all our migrations are additive).

---

## Self-Review Notes

(For the plan writer — not part of execution.)

- **Spec coverage:** all 7 spec sections mapped to PRs 1–6; the VPS swap procedure is captured in the post-PR section above. No gaps found.
- **Placeholder scan:** no "TBD"/"TODO"/"implement later". Every code block is concrete. Two places say "find via grep" (file paths that vary by current upstream sync state) — the grep commands are exact.
- **Type / name consistency:** column named `model_override` (not `model`) is used consistently from Task 6.3 onward; `appyInstallation` (camelCase) on the frontend mirrors `appy_installation` (snake_case) on the backend, both wired in Task 3.4.
- **One known fork in the road:** Task 5.2 has Path A (server-side filter) vs Path B (client-side filter) depending on what Task 5.1 discovers. This is intentional — backend support depends on what already exists.
