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
# On for new repos; verified settable on the Free plan. Existing repos are
# enabled separately (org defaults only apply to repos created after this).
dependabot_alerts_enabled_for_new_repositories               = true
dependabot_security_updates_enabled_for_new_repositories     = true
dependency_graph_enabled_for_new_repositories                = true
secret_scanning_enabled_for_new_repositories                 = true
secret_scanning_push_protection_enabled_for_new_repositories = true

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

# Global free-path opt-out is empty: per-ruleset exclude_repos/include_repos
# below scope each rule, so github-org is handled explicitly (excluded from the
# require-PR rule, included in the force-push/deletion rule).
fallback_excluded_repos = []

organization_rulesets = {
  # Standard branch protection for every repo EXCEPT this config repo.
  "default-branch-protection" = {
    enforcement   = "active"
    target        = "branch"
    include_refs  = ["~DEFAULT_BRANCH"] # the default branch of every repo
    include_repos = ["~ALL"]
    # Exclude the repo hosting this config: CI pushes state straight to its
    # default branch as github-actions[bot], so a require_pull_request rule
    # there would block the state commit. Honored by BOTH paths.
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

  # The config repo itself: protect history WITHOUT requiring PRs, so CI's
  # state-commit push (a normal fast-forward) still works while force-pushes
  # and branch deletion are blocked. No admin bypass — IaC history is locked
  # even for owners (disable this rule deliberately if you ever must rewrite).
  "config-repo-no-rewrite" = {
    enforcement   = "active"
    target        = "branch"
    include_refs  = ["~DEFAULT_BRANCH"]
    include_repos = ["github-org"]

    require_pull_request = false
    block_force_push     = true
    block_deletion       = true
    bypass_org_admins    = false
  }
}

teams = {}
