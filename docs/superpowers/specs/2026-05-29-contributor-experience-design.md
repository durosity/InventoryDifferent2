# Contributor Experience & Docker Staging Design

**Date:** 2026-05-29  
**Status:** Approved

## Context

A second contributor has been added to the GitHub repository. The current setup has solid bones (test + publish workflows, PR/issue templates) but gaps that matter now that more than one person is committing code:

- `CONTRIBUTING.md` claims "no automated test suite" — incorrect; a full test matrix exists
- No branch protection on `main` — tests pass or fail with no enforcement
- No mechanism to test Docker images before they land on `:latest` and reach end users
- No auto-review assignment when a PR is opened

This design closes those gaps with minimal process overhead, targeting a technical contributor who doesn't need bureaucratic ceremony.

---

## 1. Docker Image Staging

### 1a. `:dev` Auto-Tag (Branch-Based Staging Lane)

Add a `dev` branch as a personal staging lane. Pushing to `dev` automatically builds and pushes all 5 images tagged `:dev`:

- `wottle/inventory-api:dev`
- `wottle/inventory-web:dev`
- `wottle/inventory-storefront:dev`
- `wottle/inventory-mcp:dev`
- `wottle/inventory-showcase:dev`

**Trigger change in `publish.yml`:**
```yaml
on:
  workflow_run:
    workflows: ["Run Tests"]
    types: [completed]
    branches: [main, dev]   # ← add dev
  workflow_dispatch:
    inputs:
      image_tag:
        description: 'Docker image tag (default: latest)'
        required: false
        default: 'latest'
```

The job-level `if` condition must also be updated to allow `workflow_dispatch` runs (currently it's broken — `workflow_run.conclusion` is null on manual dispatch, so the job never executes):
```yaml
if: ${{ github.event_name == 'workflow_dispatch' || github.event.workflow_run.conclusion == 'success' }}
```

The matrix job reads the tag dynamically:
```yaml
tags: ${{ matrix.image }}:${{ inputs.image_tag || (github.event.workflow_run.head_branch == 'dev' && 'dev') || 'latest' }}
```

**Workflow:** Push pre-release work to `dev` → CI runs tests → images publish as `:dev` → pull on NAS to test → merge `dev` → `main` to promote to `:latest`.

### 1b. Manual Tag Override (`workflow_dispatch`)

The `workflow_dispatch` input `image_tag` (already in the trigger above) lets you manually build any tag from any branch:
- Trigger from GitHub UI: Actions → Publish Docker Images → Run workflow
- Enter `staging`, `pr-42`, `test-widget-feature`, or any string
- All 5 images publish with that tag

Default is `latest` so a bare manual trigger still works as today.

### 1c. Retag Workflow (Promote `:dev` → `:latest` Without Rebuilding)

A new `retag.yml` workflow lets you promote `:dev` to `:latest` in ~30 seconds by copying the Docker manifest — no source rebuild, guaranteed identical layers.

```yaml
name: Retag Docker Images
on:
  workflow_dispatch:
    inputs:
      source_tag:
        description: 'Source tag to promote (e.g. dev)'
        required: true
        default: 'dev'
      target_tag:
        description: 'Target tag (e.g. latest)'
        required: true
        default: 'latest'

jobs:
  retag:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: [api, web, storefront, mcp, showcase]
    steps:
      - uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
      - name: Retag ${{ matrix.service }}
        run: |
          docker buildx imagetools create \
            --tag wottle/inventory-${{ matrix.service }}:${{ inputs.target_tag }} \
            wottle/inventory-${{ matrix.service }}:${{ inputs.source_tag }}
```

**Normal flow:** merge `dev` → `main` (safest, rebuilds from source, tests re-run).  
**Escape hatch:** trigger `retag.yml` with `dev` → `latest` when you're confident and want to skip the rebuild.

---

## 2. CI Enforcement

### 2a. TypeScript Build Check (new CI job)

Add a `typecheck` job to `test.yml` that runs `tsc --noEmit` across api, web, and storefront in parallel. Catches type errors that tests may miss. Fast (~1–2 min).

```yaml
typecheck:
  runs-on: ubuntu-latest
  strategy:
    matrix:
      package: [api, web, storefront]
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'npm'
        cache-dependency-path: ${{ matrix.package }}/package-lock.json
    - run: npm ci
      working-directory: ${{ matrix.package }}
    - run: npx tsc --noEmit
      working-directory: ${{ matrix.package }}
```

### 2b. Branch Protection on `main` (GitHub Settings — Manual Step)

Configure in GitHub → Settings → Branches → Add rule for `main`:

- ✅ Require status checks to pass before merging
  - Required checks: `api-tests`, `mcp-tests`, `web-tests`, `typecheck`
  - (`e2e-tests` optional — it's conditional and slower)
- ✅ Require at least 1 approving review
- ✅ Dismiss stale reviews when new commits are pushed
- ✅ Do not allow bypassing the above settings

---

## 3. CODEOWNERS

New file `.github/CODEOWNERS`:
```
* @wottle
```

Auto-requests your review on every PR. No path-specific routing needed at this scale.

---

## 4. CONTRIBUTING.md Updates

Targeted corrections to the existing file:

1. **Remove** the "no automated test suite currently" line
2. **Add** a "Running tests locally" section:
   ```bash
   # Unit tests (run from each package directory)
   cd api && npm test
   cd web && npm test
   cd mcp-server && npm test

   # End-to-end tests
   docker compose -f docker-compose.test.yml up -d
   cd e2e && npx playwright test
   ```
3. **Add** a "CI pipeline" section explaining:
   - Tests + typecheck run on every PR
   - Docker images publish to `:latest` on merge to `main`
   - `:dev` images publish when pushing to the `dev` branch
   - Manual publish available via Actions → Publish Docker Images

---

## 5. PR Template Update

Add one line to the checklist in `.github/pull_request_template.md`:
```
- [ ] Tests pass locally (`npm test` in changed packages)
```

Update the Testing section header to note CI runs automatically and must pass before merge.

---

## Verification

1. Push a test commit to `dev` branch → confirm `:dev` images appear on Docker Hub
2. Open a test PR → confirm `@wottle` is auto-requested as reviewer
3. Open a PR with a TypeScript error → confirm `typecheck` job fails and blocks merge
4. Trigger `retag.yml` with `dev` → `latest` → confirm Docker Hub shows updated `:latest` digest matching `:dev`
5. Enable branch protection and verify a PR without passing checks cannot be merged
6. Confirm CONTRIBUTING.md no longer mentions "no automated test suite"
