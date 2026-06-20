# Org-level self-hosted runner GROUPS (the access-scoping containers that decide
# which repos/workflows may use a set of self-hosted runners).
#
# PAID: creating additional runner groups beyond the org's built-in "Default"
# group requires GitHub Team or higher; on Free the API returns
# 403 "Upgrade to GitHub Team". Gated by var.paid_plan_features_enabled exactly
# like the org rulesets — while the flag is false, local.runner_groups is empty,
# so NO resource is created and NO API call is made (no 403). There is no free
# fallback (unlike rulesets): on Free, register runners into the built-in
# "Default" group instead — no Terraform needed.
#
# SCOPE: this manages the runner GROUP only. The runner AGENT is a daemon
# installed on a host (`./config.sh --runner-group "<name>" ...`), which
# Terraform does not manage — provision it out of band (a setup script).

locals {
  runner_groups = var.paid_plan_features_enabled ? var.actions_runner_groups : {}

  # Repo names referenced by any "selected"-visibility group, deduped, so each
  # name is resolved to its numeric repository ID exactly once. Empty (no data
  # lookups) whenever the paid flag is off or no group targets selected repos.
  runner_group_repo_names = toset(flatten([
    for g in values(local.runner_groups) :
    g.selected_repositories if g.visibility == "selected"
  ]))
}

# Resolve repo names -> numeric IDs (the API/resource wants IDs; names are what
# humans maintain in tfvars). Provider owner is var.github_owner, so name alone
# scopes to this org.
data "github_repository" "runner_group" {
  for_each = local.runner_group_repo_names
  name     = each.value
}

resource "github_actions_runner_group" "this" {
  for_each = local.runner_groups

  name       = each.key
  visibility = each.value.visibility

  # Keep self-hosted runners off public-repo PRs unless explicitly opted in:
  # a public-repo workflow can run untrusted PR code on the runner host.
  allows_public_repositories = each.value.allows_public_repositories

  restricted_to_workflows = each.value.restricted_to_workflows
  selected_workflows      = each.value.restricted_to_workflows ? each.value.selected_workflows : []

  # Only meaningful for visibility = "selected"; null (omitted) otherwise.
  selected_repository_ids = each.value.visibility == "selected" ? [
    for name in each.value.selected_repositories :
    data.github_repository.runner_group[name].repo_id
  ] : null
}
