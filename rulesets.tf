# Org-wide branch/tag rulesets — the proper "inter-repo" enforcement mechanism.
#
# REQUIRES the org to be on the GitHub Team plan (or higher). On the Free plan
# the rulesets API returns 403 ("Upgrade to GitHub Team to enable this
# feature"). Gated by var.paid_plan_features_enabled: while that is false this
# creates nothing (no API call), even if organization_rulesets is populated.
# Flip the flag to true after upgrading, then merge to main (CI applies).
#
# While the flag is false, repo_rulesets.tf applies the SAME rule definitions
# per-repo as a free fallback. Exactly one path is active at a time.

resource "github_organization_ruleset" "this" {
  for_each = var.paid_plan_features_enabled ? var.organization_rulesets : {}

  name        = each.key
  target      = each.value.target
  enforcement = each.value.enforcement

  conditions {
    ref_name {
      include = each.value.include_refs
      exclude = each.value.exclude_refs
    }
    repository_name {
      include = each.value.include_repos
      exclude = each.value.exclude_repos
    }
  }

  # Let org admins push past the rules (avoids locking out a small org).
  dynamic "bypass_actors" {
    for_each = each.value.bypass_org_admins ? [1] : []
    content {
      actor_id    = 1 # the OrganizationAdmin role
      actor_type  = "OrganizationAdmin"
      bypass_mode = "always"
    }
  }

  rules {
    creation                = each.value.block_creation
    deletion                = each.value.block_deletion
    non_fast_forward        = each.value.block_force_push
    required_linear_history = each.value.require_linear_history
    required_signatures     = each.value.require_signatures

    dynamic "pull_request" {
      for_each = each.value.require_pull_request ? [1] : []
      content {
        required_approving_review_count   = each.value.required_approving_reviews
        require_code_owner_review         = each.value.require_code_owner_review
        dismiss_stale_reviews_on_push     = each.value.dismiss_stale_reviews_on_push
        required_review_thread_resolution = each.value.require_conversation_resolution
      }
    }

    dynamic "required_status_checks" {
      for_each = length(each.value.required_status_checks) > 0 ? [1] : []
      content {
        strict_required_status_checks_policy = true
        dynamic "required_check" {
          for_each = each.value.required_status_checks
          content {
            context = required_check.value
          }
        }
      }
    }
  }
}
