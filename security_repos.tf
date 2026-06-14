# Drift-protect security on repos that predate the org-wide new-repo defaults.
# New repos inherit the defaults at creation (org.tf); these existing repos are
# adopted here so the drift workflow re-enables security (and reverts an
# unexpected visibility change) if anything is flipped in the UI.
#
# Secret scanning + push protection live only on github_repository, so we adopt
# the repos there with a broad ignore_changes: Terraform enforces ONLY the
# security_and_analysis block + visibility, and ignores every other repo
# attribute (features, merge options, templates, archive state) so it never
# fights you on normal repo settings. Vulnerability alerts and Dependabot
# security updates use their dedicated resources.

locals {
  security_managed_repos = toset(["topos", "github-org"])
}

# Config-driven import: CI performs the import on apply (keeps CI the sole state
# writer — no local `terraform import`). Safe to remove after the first apply.
import {
  for_each = local.security_managed_repos
  to       = github_repository.managed[each.key]
  id       = each.key
}

import {
  for_each = local.security_managed_repos
  to       = github_repository_vulnerability_alerts.managed[each.key]
  id       = each.key
}

import {
  for_each = local.security_managed_repos
  to       = github_repository_dependabot_security_updates.managed[each.key]
  id       = each.key
}

resource "github_repository" "managed" {
  for_each = local.security_managed_repos

  name       = each.key
  visibility = "public" # both repos are public; drift-protects visibility

  security_and_analysis {
    secret_scanning {
      status = "enabled"
    }
    secret_scanning_push_protection {
      status = "enabled"
    }
  }

  # Enforce only security + visibility above. Everything else is the repo
  # owner's to change in the UI without Terraform reverting it.
  lifecycle {
    ignore_changes = [
      description, homepage_url, topics,
      has_issues, has_projects, has_wiki, has_downloads, has_discussions,
      allow_merge_commit, allow_squash_merge, allow_rebase_merge,
      allow_auto_merge, allow_update_branch, delete_branch_on_merge,
      merge_commit_message, merge_commit_title,
      squash_merge_commit_message, squash_merge_commit_title,
      auto_init, gitignore_template, license_template,
      pages, template, is_template,
      archived, archive_on_destroy, ignore_vulnerability_alerts_during_read,
    ]
  }
}

resource "github_repository_vulnerability_alerts" "managed" {
  for_each = local.security_managed_repos

  repository = each.key
  enabled    = true
}

resource "github_repository_dependabot_security_updates" "managed" {
  for_each = local.security_managed_repos

  repository = each.key
  enabled    = true
}
