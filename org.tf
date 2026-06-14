# Organization-level settings.
# Import the existing org before the first apply (see README):
#   terraform import github_organization_settings.this <org-id>

resource "github_organization_settings" "this" {
  billing_email = var.billing_email
  name          = var.company_name != "" ? var.company_name : null

  default_repository_permission           = var.default_repository_permission
  members_can_create_public_repositories  = var.members_can_create_public_repositories
  members_can_create_private_repositories = var.members_can_create_private_repositories

  # Derived: members can create a repo if they can create either visibility.
  members_can_create_repositories = (
    var.members_can_create_public_repositories ||
    var.members_can_create_private_repositories
  )

  web_commit_signoff_required           = var.web_commit_signoff_required
  members_can_fork_private_repositories = var.members_can_fork_private_repositories

  # Security features turned on automatically for newly created repos.
  dependabot_alerts_enabled_for_new_repositories               = var.dependabot_alerts_enabled_for_new_repositories
  dependabot_security_updates_enabled_for_new_repositories     = var.dependabot_security_updates_enabled_for_new_repositories
  dependency_graph_enabled_for_new_repositories                = var.dependency_graph_enabled_for_new_repositories
  secret_scanning_enabled_for_new_repositories                 = var.secret_scanning_enabled_for_new_repositories
  secret_scanning_push_protection_enabled_for_new_repositories = var.secret_scanning_push_protection_enabled_for_new_repositories

  # NOTE: 2FA enforcement (two_factor_requirement_enabled) is read-only in the
  # provider and cannot be set here — toggle it in the org's UI under
  # Settings > Authentication security. Every member must have 2FA enabled
  # first, or GitHub rejects the change.
}
