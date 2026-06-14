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
| `teams.tf` | Teams + memberships (org-level) |
| `outputs.tf` | Convenience outputs |
| `.github/workflows/terraform.yml` | CI: fmt/validate/plan on PR, apply on main |
| `.github/workflows/drift.yml` | Scheduled drift detection + auto-reconcile |

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

## First run / fresh clone

The org resources are **already imported and recorded in the committed
`terraform.tfstate`**, so a fresh clone needs no import:

```bash
cd ~/private/github-org
export GITHUB_TOKEN=<token with admin:org>   # only needed for a local plan
terraform init
terraform plan   # reads committed state; should report: No changes
```

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

These are written and ready in `terraform.tfvars`, but gated behind a single
flag so they never break `apply` on the free plan:

```hcl
paid_plan_features_enabled = false   # flip to true after upgrading to Team
```

- **`organization_rulesets`** — org-wide branch protection on every repo's
  default branch (require PR, block force-push, block deletion, require
  conversation resolution; org admins can bypass). While the flag is `false`,
  Terraform makes **no rulesets API call**, so there's no 403.

To activate: upgrade the org to Team, set `paid_plan_features_enabled = true`,
then `terraform apply`.

## Hardening backlog

The org currently allows public repo creation, base permission `read`, and has
2FA disabled. Recommended once ready (see the commented block in
`terraform.tfvars`):

- `members_can_create_public_repositories = false`
- `web_commit_signoff_required = true`
- Enable 2FA enforcement in the org UI (Settings > Authentication security) —
  this is **not** settable via the provider, and every member must have 2FA on
  first or GitHub rejects it.

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
