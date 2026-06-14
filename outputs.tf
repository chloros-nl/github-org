output "organization" {
  description = "Managed organization login."
  value       = var.github_owner
}

output "managed_teams" {
  description = "Teams under Terraform management."
  value       = sort(keys(github_team.this))
}
