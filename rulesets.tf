# Org-wide branch/tag rulesets — the proper "inter-repo" enforcement mechanism.
#
# REQUIRES the org to be on the GitHub Team plan (or higher). On the Free plan
# the rulesets API returns 403 ("Upgrade to GitHub Team to enable this
# feature"), so this resource is COMMENTED OUT entirely — it never reaches the
# API. While it is commented out, repo_rulesets.tf applies the SAME rule
# definitions (var.organization_rulesets) per-repo as a free fallback (public
# repos only), so branch protection still works on Free.
#
# TO ENABLE after upgrading to GitHub Team:
#   1. Uncomment the resource block below.
#   2. Set paid_plan_features_enabled = true in terraform.tfvars (this turns the
#      free per-repo fallback OFF and activates the for_each here).
#   3. Merge to main; CI applies. The per-repo fallback rulesets are destroyed
#      and the org-wide ruleset is created in the same apply.
#
# resource "github_organization_ruleset" "this" {
#   for_each = var.paid_plan_features_enabled ? var.organization_rulesets : {}
#
#   name        = each.key
#   target      = each.value.target
#   enforcement = each.value.enforcement
#
#   conditions {
#     ref_name {
#       include = each.value.include_refs
#       exclude = each.value.exclude_refs
#     }
#     repository_name {
#       include = each.value.include_repos
#       exclude = each.value.exclude_repos
#     }
#   }
#
#   # Let org admins push past the rules (avoids locking out a small org).
#   dynamic "bypass_actors" {
#     for_each = each.value.bypass_org_admins ? [1] : []
#     content {
#       # OrganizationAdmin is role-based; the API stores no numeric id and
#       # returns null (refreshed as 0). Using 0 avoids a perpetual plan diff.
#       actor_id    = 0
#       actor_type  = "OrganizationAdmin"
#       bypass_mode = "always"
#     }
#   }
#
#   rules {
#     creation                = each.value.block_creation
#     deletion                = each.value.block_deletion
#     non_fast_forward        = each.value.block_force_push
#     required_linear_history = each.value.require_linear_history
#     required_signatures     = each.value.require_signatures
#
#     dynamic "pull_request" {
#       for_each = each.value.require_pull_request ? [1] : []
#       content {
#         required_approving_review_count   = each.value.required_approving_reviews
#         require_code_owner_review         = each.value.require_code_owner_review
#         dismiss_stale_reviews_on_push     = each.value.dismiss_stale_reviews_on_push
#         required_review_thread_resolution = each.value.require_conversation_resolution
#       }
#     }
#
#     dynamic "required_status_checks" {
#       for_each = length(each.value.required_status_checks) > 0 ? [1] : []
#       content {
#         strict_required_status_checks_policy = true
#         dynamic "required_check" {
#           for_each = each.value.required_status_checks
#           content {
#             context = required_check.value
#           }
#         }
#       }
#     }
#   }
# }
