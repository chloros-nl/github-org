# Teams, their memberships, and their repo access. All optional — empty by
# default since the org currently has no teams. Populate var.teams to use.

resource "github_team" "this" {
  for_each = var.teams

  name        = each.key
  description = each.value.description
  privacy     = each.value.privacy
}

locals {
  # Flatten teams -> members into a single map for for_each.
  team_members = merge([
    for team_name, team in var.teams : {
      for username, role in team.members :
      "${team_name}:${username}" => {
        team     = team_name
        username = username
        role     = role
      }
    }
  ]...)
}

resource "github_team_membership" "this" {
  for_each = local.team_members

  team_id  = github_team.this[each.value.team].id
  username = each.value.username
  role     = each.value.role
}
