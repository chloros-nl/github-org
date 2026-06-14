# Free-plan fallback for the org-wide rulesets in rulesets.tf.
#
# Organization rulesets require the GitHub Team plan. On the Free plan we get
# equivalent protection by applying a REPOSITORY ruleset to each repo
# individually — repo rulesets are free for both public and private repos.
#
# This path and the org-ruleset path are driven by the SAME definitions
# (var.organization_rulesets) and the SAME toggle, but inverted, so exactly one
# is ever active and flipping the flag switches over cleanly:
#
#   paid_plan_features_enabled = false  -> per-repo rulesets here (free)
#   paid_plan_features_enabled = true   -> org rulesets in rulesets.tf (paid)

# Enumerate the org's non-archived repos (only needed in fallback mode).
data "github_repositories" "all" {
  count           = var.paid_plan_features_enabled ? 0 : 1
  query           = "org:${var.github_owner} archived:false"
  include_repo_id = false
}

locals {
  # try() keeps this safe when count = 0 (paid mode): no data source to index.
  fallback_repo_names = try(data.github_repositories.all[0].names, [])

  # One repository ruleset per {ruleset definition} x {repo}, scoped to match the
  # org (paid) path: honor include_repos and exclude_repos, plus the fallback-only
  # opt-out list. NOTE: the org path matches include/exclude as GitHub fnmatch
  # patterns; this free path matches by EXACT repo name (and the "~ALL" wildcard)
  # only — globs like "test-*" work on the paid path but not here.
  # The repo hosting this config (fallback_excluded_repos default) is excluded
  # because CI pushes state straight to its default branch as github-actions[bot]
  # — a require_pull_request rule there would block the state commit.
  repo_rulesets = {
    for pair in flatten([
      for rs_name, rs in var.organization_rulesets : [
        for repo in local.fallback_repo_names : {
          key     = "${rs_name}:${repo}"
          rs_name = rs_name
          repo    = repo
          spec    = rs
        }
        if(contains(rs.include_repos, "~ALL") || contains(rs.include_repos, repo)) &&
        !contains(rs.exclude_repos, repo) &&
        !contains(var.fallback_excluded_repos, repo)
      ]
    ]) : pair.key => pair
  }
}

resource "github_repository_ruleset" "fallback" {
  for_each = local.repo_rulesets

  name        = each.value.rs_name
  repository  = each.value.repo
  target      = each.value.spec.target
  enforcement = each.value.spec.enforcement

  conditions {
    ref_name {
      include = each.value.spec.include_refs
      exclude = each.value.spec.exclude_refs
    }
  }

  dynamic "bypass_actors" {
    for_each = each.value.spec.bypass_org_admins ? [1] : []
    content {
      actor_id    = 1 # the OrganizationAdmin role
      actor_type  = "OrganizationAdmin"
      bypass_mode = "always"
    }
  }

  rules {
    creation                = each.value.spec.block_creation
    deletion                = each.value.spec.block_deletion
    non_fast_forward        = each.value.spec.block_force_push
    required_linear_history = each.value.spec.require_linear_history
    required_signatures     = each.value.spec.require_signatures

    dynamic "pull_request" {
      for_each = each.value.spec.require_pull_request ? [1] : []
      content {
        required_approving_review_count   = each.value.spec.required_approving_reviews
        require_code_owner_review         = each.value.spec.require_code_owner_review
        dismiss_stale_reviews_on_push     = each.value.spec.dismiss_stale_reviews_on_push
        required_review_thread_resolution = each.value.spec.require_conversation_resolution
      }
    }

    dynamic "required_status_checks" {
      for_each = length(each.value.spec.required_status_checks) > 0 ? [1] : []
      content {
        strict_required_status_checks_policy = true
        dynamic "required_check" {
          for_each = each.value.spec.required_status_checks
          content {
            context = required_check.value
          }
        }
      }
    }
  }
}
