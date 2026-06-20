output "organization" {
  description = "Managed organization login."
  value       = var.github_owner
}

output "managed_teams" {
  description = "Teams under Terraform management."
  value       = sort(keys(github_team.this))
}

output "managed_runner_groups" {
  description = "Self-hosted runner groups under Terraform management (empty on Free until paid_plan_features_enabled = true)."
  value       = sort(keys(github_actions_runner_group.this))
}

output "branch_protection_mode" {
  description = "Which ruleset path the paid flag selects. NOTE: the org ruleset is commented out in rulesets.tf, so the paid value enforces nothing until that resource is uncommented — an on flag alone just disables the free fallback."
  value       = var.paid_plan_features_enabled ? "paid flag on (org ruleset enforces only if uncommented in rulesets.tf)" : "per-repo fallback (free, public repos only)"
}

output "fallback_protected_repos" {
  description = "Public repos covered by the free per-repo ruleset fallback (private repos are excluded on Free). Empty when paid_plan_features_enabled = true, which disables this fallback — protection then depends on the org ruleset in rulesets.tf, which must be uncommented to enforce (an empty list does not by itself mean the paid path is active)."
  value       = sort(distinct([for k in keys(github_repository_ruleset.fallback) : github_repository_ruleset.fallback[k].repository]))
}
