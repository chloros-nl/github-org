# Org-wide GitHub Actions policy. Singleton org resource — import once with:
#   terraform import github_actions_organization_permissions.this chloros-nl

resource "github_actions_organization_permissions" "this" {
  allowed_actions      = var.actions_allowed_actions
  enabled_repositories = var.actions_enabled_repositories
  sha_pinning_required = var.actions_sha_pinning_required

  # Only meaningful when allowed_actions = "selected".
  dynamic "allowed_actions_config" {
    for_each = var.actions_allowed_actions == "selected" ? [1] : []
    content {
      github_owned_allowed = var.actions_allowed_actions_config.github_owned_allowed
      verified_allowed     = var.actions_allowed_actions_config.verified_allowed
      patterns_allowed     = var.actions_allowed_actions_config.patterns_allowed
    }
  }
}
