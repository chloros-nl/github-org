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
  description = "Repos covered by the free per-repo ruleset fallback (empty when on the paid org-ruleset path)."
  value       = sort([for k in keys(github_repository_ruleset.fallback) : github_repository_ruleset.fallback[k].repository])
}
