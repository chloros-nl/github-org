# github-org

Terraform configuration that manages the [`chloros-nl`](https://github.com/chloros-nl)
GitHub organization as code — **organization-level settings only**: org
settings/policies, security defaults for new repos, org-wide Actions policy,
org-wide rulesets, and teams. Per-repository settings (merge options, wiki,
per-repo branch protection, team→repo access) are intentionally **out of scope**
and left to each repo.

## Layout

| File | Purpose |
|------|---------|
| `versions.tf` | Terraform + provider version pins, backend config |
| `providers.tf` | `integrations/github` provider (auth via `$GITHUB_TOKEN`) |
| `variables.tf` | Input variable definitions |
| `terraform.tfvars` | **Live values** for the org (committed; no secrets) |
| `terraform.tfvars.example` | Reference example with all knobs |
| `org.tf` | `github_organization_settings` (policy + new-repo security defaults) |
| `actions.tf` | `github_actions_organization_permissions` (org-wide Actions policy) |
| `rulesets.tf` | `github_organization_ruleset` (org-wide branch rules — **paid**, gated) |
| `repo_rulesets.tf` | `github_repository_ruleset` per repo (free fallback, active when the paid flag is off) |
| `runner_groups.tf` | `github_actions_runner_group` (org self-hosted runner groups — **paid**, gated) |
| `security_repos.tf` | Drift-protects security + visibility on the pre-existing repos |
| `teams.tf` | Teams + memberships (org-level) |
| `outputs.tf` | Convenience outputs |
| `.github/workflows/terraform.yml` | CI: fmt/validate/plan on PR, apply on main |
| `.github/workflows/drift.yml` | Scheduled drift detection + auto-reconcile |
| `.github/dependabot.yml` | Auto-update pinned actions + the github provider |

## Prerequisites

- Terraform >= 1.6 (installed at `~/.local/bin/terraform`).
- A token with **`admin:org`, `repo`, `workflow`** scopes exported as
  `GITHUB_TOKEN`. Your current `gh` token only has `read:org` — it can read
  but **cannot apply**. Create a dedicated token:

  ```bash
  # Classic PAT with admin:org, repo, workflow — then:
  export GITHUB_TOKEN=ghp_xxx
  ```

  For CI, use a **GitHub App** installation token instead of a PAT (see the
  workflow) — it isn't tied to a person and is easy to rotate.

  **App permissions** (set on the GitHub App, approved on the org install):
  - **Organization → Administration: Read & write** — org settings, Actions
    policy, and the *paid* org-wide ruleset.
  - **Organization → Members: Read & write** — only if you manage `teams`.
  - **Organization → Self-hosted runners: Read & write** — only if you manage
    `actions_runner_groups` (the *paid* runner-group path). Repo→Metadata (below)
    covers resolving the `selected_repositories` names to IDs.
  - **Repository → Administration: Read & write** — **required for the free
    per-repo ruleset fallback** (`repo_rulesets.tf`). Creating a *repository*
    ruleset is a repo-admin action; without it the App gets
    `403 Resource not accessible by integration`. (The paid org-ruleset path
    does **not** need this — org Administration covers it.)
  - **Repository → Metadata: Read** — mandatory baseline.

## First run / fresh clone

The org resources are **already imported and recorded in the committed
`terraform.tfstate`**, so a fresh clone needs no import:

```bash
cd ~/private/github-org
export GITHUB_TOKEN=<token with admin:org>   # only needed for a local plan
terraform init
terraform plan   # reads committed state; No changes in steady state
```

(CI commits state after every apply, so a clone is in sync. Right after a config
change merges, the first plan may show the pending adds until CI applies them.)

The one-time bootstrap that imported the existing org (`make import-org` /
`make import-actions`) has already been run; re-running it now errors with
"Resource already managed by Terraform".

## Day-to-day

Changes ship through Git — **CI is the sole state writer** (see "State"), so
don't `apply` locally. Locally you only preview:

```bash
make check    # fmt + validate
make plan     # preview against the committed state
```

## Adding things

- **A team**: add an entry to `teams` in `terraform.tfvars` with its `members`.
- **Org policy**: flip the org-level variables (repo-creation privileges, base
  permission, web commit sign-off).

See `terraform.tfvars.example` for the full shape. Per-repo settings are
deliberately not managed here.

## Paid-plan features (gated)

Some org-wide controls require a **paid GitHub plan (Team or higher)**. The
`chloros-nl` org is currently on **Free**, where the org rulesets API returns
`403 "Upgrade to GitHub Team to enable this feature"`.

The paid resources are **commented out** in their `.tf` files so they never
reach the API on Free, and the `paid_plan_features_enabled` flag stays `false`:

```hcl
paid_plan_features_enabled = false   # see each paid resource's "TO ENABLE" header
```

- **`organization_rulesets`** (`rulesets.tf`) — org-wide branch protection on
  every repo's default branch (require PR, block force-push, block deletion,
  require conversation resolution; org admins can bypass). The
  `github_organization_ruleset` resource is **commented out**; the rule
  definitions in `var.organization_rulesets` are still consumed by the free
  per-repo fallback below. To enable: upgrade to Team, **uncomment the resource**
  in `rulesets.tf`, then set `paid_plan_features_enabled = true`.
- **`actions_runner_groups`** (`runner_groups.tf`) — org-level self-hosted
  runner groups, used to scope a set of self-hosted runners to specific repos
  (`visibility`) and workflows (`restricted_to_workflows`). Creating groups
  beyond the built-in **Default** group requires Team, so the
  `github_actions_runner_group` resource (and its `managed_runner_groups`
  output) is **commented out**. **Unlike rulesets there is no free fallback** —
  on Free, register runners into the Default group (no Terraform needed). To
  enable: upgrade to Team, uncomment the resource in `runner_groups.tf` and the
  output in `outputs.tf`, then set `paid_plan_features_enabled = true` and add
  groups to `actions_runner_groups`. This manages the *group* only; the runner
  **agent** is a daemon installed on a host (`./config.sh --runner-group
  "<name>" ...`), provisioned out of band. Keep `allows_public_repositories =
  false` so a public-repo PR can't run untrusted code on the runner host, and
  prefer `visibility = "selected"` / `restricted_to_workflows` to limit blast
  radius.

### Free fallback: per-repo rulesets (public repos only)

So you get branch protection *now*, on Free, `repo_rulesets.tf` applies the
**same `organization_rulesets` definitions per repository**. The single
`paid_plan_features_enabled` flag switches between the two paths, and exactly
one is ever active:

| flag | active path | how it covers repos |
|------|-------------|---------------------|
| `false` (now) | per-repo `github_repository_ruleset` | enumerates org **public** repos, one ruleset per matching `organization_rulesets` definition |
| `true` (after upgrade + uncomment) | one `github_organization_ruleset` | `include_repos = ["~ALL"]`, all repos incl. private |

**Limitation — private repos are unprotected on Free.** Repository rulesets are
free for **public** repos only; on a **private** repo the rulesets API returns
`403 "Upgrade to GitHub Pro or make this repository public"`. The free fallback
therefore enumerates public repos only (`is:public`), so private repos
(`topos`, `topos-web`, `morphos`, `chloros-web-app`) get **no ruleset
protection** until you upgrade to Team, uncomment the org ruleset, and flip the
flag — at which point the org-wide ruleset covers private repos too.

Uncommenting the org ruleset and flipping the flag (then merging) swaps them
cleanly (the per-repo fallback rulesets are destroyed and the org ruleset
created in the same apply). The rule *definitions* live once in
`organization_rulesets`, so both paths enforce identical rules; only their
**coverage** differs (free path: public repos; paid path: all repos).

**Exclusions & the config repo.** Both paths honor each ruleset's
`include_repos`/`exclude_repos`, and the free path also honors
`var.fallback_excluded_repos`. The repo hosting this config (`github-org`) is
**excluded from the `require_pull_request` ruleset** (`default-branch-protection`)
— CI pushes state straight to its default branch as `github-actions[bot]` (not an
org admin, so the admin bypass doesn't apply), and a PR-required rule would block
the state commit. It is instead covered by a separate **`config-repo-no-rewrite`**
ruleset that blocks force-pushes and branch deletion **without** requiring PRs, so
CI's normal fast-forward push still works while the IaC history can't be rewritten
(no admin bypass — disable that rule deliberately if you ever must rewrite).
Apply the same split to any other repo whose CI pushes directly to its default
branch as a non-admin.

**Scope matching differs by path.** The paid org ruleset matches
`include_repos`/`exclude_repos` as GitHub **fnmatch patterns** (e.g. `test-*`);
the free per-repo path matches by **exact repo name** (plus the `~ALL`
wildcard). Stick to exact names + `~ALL` if you want identical behavior across
the toggle.

**Caveats.** The free path enumerates repos via the search API, which can lag a
few minutes for a brand-new repo (the daily drift run picks it up); the paid
`~ALL` ruleset has no such lag. The free path also skips **archived** repos
(harmless — archived repos are read-only, so a branch rule would be a no-op).

To switch to the paid path: upgrade the org to Team, **uncomment the
`github_organization_ruleset` resource in `rulesets.tf`**, set
`paid_plan_features_enabled = true`, then commit and merge to `main` — CI
applies it (don't `terraform apply` locally; see "State"). Setting the flag
without uncommenting the resource only disables the free fallback and enforces
nothing.

## Repository security

New repos get Dependabot alerts + security updates, dependency graph, secret
scanning, and push protection automatically (the
`*_enabled_for_new_repositories` settings, on by default here; free for public
repos). These org defaults apply **only to repos created after** they were set —
existing repos are enabled out-of-band (not via this config, to keep it
org-level), so enable the same features on any repo that predates them.

`.github/dependabot.yml` keeps the pinned actions and the `integrations/github`
provider current. Dependabot PRs run without repo secrets, so `terraform.yml`
skips the App-token/plan steps for `dependabot[bot]` and only fmt/validates.

The org defaults only cover *future* repos, so the two pre-existing repos are
adopted in `security_repos.tf` and **drift-protected**. `local.security_managed_repos`
maps each repo to its intended visibility (`github-org` → `public`, `topos` →
`private`), which Terraform enforces so an unexpected visibility flip is reverted.
It also enforces vulnerability alerts and Dependabot security updates on both
(free for private repos too), plus secret scanning + push protection on **public
repos only** — those are GitHub Advanced Security features, free for public repos
but not manageable on private repos on the Free plan (enabling them via the API
403s). A broad
`ignore_changes` leaves every other repo setting to you. To cover another
**existing** repo, add a `"name" = "public"|"private"` entry to
`local.security_managed_repos` and, because the repo already exists, adopt it on
the next apply with a temporary `import` block (or `terraform import` each
address) — then remove the block. (The original import blocks were removed once
the current repos were in state.)

## Hardening backlog

Still open (deliberate, your call):

- **2FA enforcement** is **off** — enable in the org UI (Settings >
  Authentication security); **not** settable via the provider, and every member
  must have 2FA on first or GitHub rejects it.
- `members_can_create_public_repositories = true` — tighten to `false` if you
  want to gate public-repo creation.
- `web_commit_signoff_required = false` — flip to `true` to require sign-off.

## State

`terraform.tfstate` is **committed to this repo** (no remote backend). That is
safe here because this org-level state contains **no secrets** — no tokens, no
provider-flagged sensitive attributes (the GitHub token is never stored in
state). Only `*.tfstate.backup` is gitignored.

**CI is the sole state writer.** On merge to `main` (or a `workflow_dispatch`
with `action=apply`), CI runs `terraform apply` and commits the updated
`terraform.tfstate` back with `[skip ci]`. To keep this consistent:

- **Do not run `terraform apply` locally** against the org — let CI do it, or
  you'll diverge from the committed state. Local `terraform plan` is fine.
- A `concurrency: terraform-state` group serializes runs so two applies can't
  write state at once. Git provides no real lock — this group is the guard.
- If you ever add a resource whose state *does* hold a secret, stop committing
  state and switch to the encrypted remote backend stub in `versions.tf`.

## Keeping the org in sync (drift)

`drift.yml` runs daily (06:17 UTC, plus manual `workflow_dispatch`) and keeps
the live org matching this repo — GitOps style:

1. `terraform plan -detailed-exitcode` — exit `0` = in sync, `2` = drift.
2. On drift it **auto-reconciles** (`terraform apply`), pulling the org back to
   the committed config, and commits the updated state.
3. It records every correction in a single rolling **`terraform-drift`** tracking
   issue (with the plan), so a UI change that gets reverted is auditable. If a
   reconcile *fails*, the issue says so and the run fails.

So a setting changed by hand in the GitHub UI is reverted within a day. To make
an intended change, edit the `.tf`/`.tfvars` here — never the UI. To switch to
**alert-only** (notify, don't auto-fix), delete the `Reconcile drift` /
`Commit reconciled state` steps; the issue step still reports.

## Limits

- A few org settings (some billing, SAML/SSO on certain plans, parts of the
  security center) aren't exposed by the API and must stay in the web UI.
