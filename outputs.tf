output "organization" {
  description = "Managed organization login."
  value       = var.github_owner
}

output "managed_teams" {
  description = "Teams under Terraform management."
  value       = sort(keys(github_team.this))
}

output "branch_protection_mode" {
  description = "Which ruleset path is active."
  value       = var.paid_plan_features_enabled ? "organization ruleset (paid)" : "per-repo fallback (free)"
}

output "fallback_protected_repos" {
  description = "Public repos covered by the free per-repo ruleset fallback (private repos are excluded on Free). Empty when paid_plan_features_enabled = true, which disables this fallback — protection then depends on the org ruleset in rulesets.tf, which must be uncommented to enforce (an empty list does not by itself mean the paid path is active)."
  value       = sort(distinct([for k in keys(github_repository_ruleset.fallback) : github_repository_ruleset.fallback[k].repository]))
}
