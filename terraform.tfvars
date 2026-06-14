# Live configuration for the chloros-nl GitHub organization.
# Org-level only — individual repository settings (merge options, wiki, branch
# protection) are intentionally NOT managed here; those are per-repo.

github_owner  = "chloros-nl"
billing_email = "yvoh@protonmail.com"

# --- member privileges / base policy ---------------------------------------
default_repository_permission           = "read"
members_can_create_public_repositories  = true
members_can_create_private_repositories = true
members_can_fork_private_repositories   = false
web_commit_signoff_required             = false

# --- security defaults for NEW repos (free for public repos) ----------------
# Currently all off (matches the org). Flip to true to harden new repos.
dependabot_alerts_enabled_for_new_repositories               = false
dependabot_security_updates_enabled_for_new_repositories     = false
dependency_graph_enabled_for_new_repositories                = false
secret_scanning_enabled_for_new_repositories                 = false
secret_scanning_push_protection_enabled_for_new_repositories = false

# --- org-wide Actions policy -----------------------------------------------
actions_allowed_actions      = "all" # all | local_only | selected
actions_enabled_repositories = "all" # all | none
actions_sha_pinning_required = false

# ---------------------------------------------------------------------------
# PAID-PLAN FEATURES
# ---------------------------------------------------------------------------
# Master flag. Org rulesets require GitHub Team (the Free plan returns 403).
# Settings below are written and ready; they activate only when this is true.
paid_plan_features_enabled = false

# Org-wide branch protection on every repo's default branch. Applies the moment
# paid_plan_features_enabled = true (after upgrading to Team).
organization_rulesets = {
  "default-branch-protection" = {
    enforcement   = "active"
    target        = "branch"
    include_refs  = ["~DEFAULT_BRANCH"] # the default branch of every repo
    include_repos = ["~ALL"]
    # Exclude the repo hosting this config: CI pushes state straight to its
    # default branch as github-actions[bot], so a require_pull_request rule
    # there would block the state commit. Honored by BOTH the org-ruleset
    # (paid) and per-repo fallback (free) paths.
    exclude_repos = ["github-org"]

    require_pull_request            = true
    required_approving_reviews      = 0 # bump to 1+ once there's >1 member
    require_conversation_resolution = true
    dismiss_stale_reviews_on_push   = true
    required_status_checks          = [] # e.g. ["build", "test"]

    block_force_push  = true
    block_deletion    = true
    bypass_org_admins = true # admins can still push directly
  }
}

teams = {}
