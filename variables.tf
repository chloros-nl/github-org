variable "github_owner" {
  description = "GitHub organization login this config manages."
  type        = string
  default     = "chloros-nl"
}

variable "billing_email" {
  description = "Organization billing email."
  type        = string
  default     = "yvoh@protonmail.com"
}

variable "company_name" {
  description = "Organization display name (the org 'name' field). Empty leaves it unset."
  type        = string
  default     = ""
}

variable "default_repository_permission" {
  description = "Base permission members get on all org repos: none | read | write | admin."
  type        = string
  default     = "read"

  validation {
    condition     = contains(["none", "read", "write", "admin"], var.default_repository_permission)
    error_message = "Must be one of: none, read, write, admin."
  }
}

variable "members_can_create_public_repositories" {
  description = "Allow members to create public repositories."
  type        = bool
  default     = true
}

variable "members_can_create_private_repositories" {
  description = "Allow members to create private repositories."
  type        = bool
  default     = true
}

variable "web_commit_signoff_required" {
  description = "Require contributors to sign off on web-based commits."
  type        = bool
  default     = false
}

variable "members_can_fork_private_repositories" {
  description = "Allow members to fork private org repos."
  type        = bool
  default     = false
}

# --- Security defaults applied to NEW repositories (org-wide) ----------------
# Free for public repos. advanced_security/code-scanning need GitHub Advanced
# Security (paid) and are intentionally not managed here.

variable "dependabot_alerts_enabled_for_new_repositories" {
  type    = bool
  default = false
}

variable "dependabot_security_updates_enabled_for_new_repositories" {
  type    = bool
  default = false
}

variable "dependency_graph_enabled_for_new_repositories" {
  type    = bool
  default = false
}

variable "secret_scanning_enabled_for_new_repositories" {
  type    = bool
  default = false
}

variable "secret_scanning_push_protection_enabled_for_new_repositories" {
  type    = bool
  default = false
}

# --- Org-wide GitHub Actions policy -----------------------------------------

variable "actions_allowed_actions" {
  description = "Which actions/workflows may run org-wide: all | local_only | selected."
  type        = string
  default     = "all"
  validation {
    condition     = contains(["all", "local_only", "selected"], var.actions_allowed_actions)
    error_message = "Must be one of: all, local_only, selected."
  }
}

variable "actions_enabled_repositories" {
  description = "Which repos may run Actions org-wide: all | none. (\"selected\" needs per-repo IDs and is out of scope here.)"
  type        = string
  default     = "all"
  validation {
    condition     = contains(["all", "none"], var.actions_enabled_repositories)
    error_message = "Must be one of: all, none."
  }
}

variable "actions_sha_pinning_required" {
  description = "Require actions to be pinned to a full-length commit SHA."
  type        = bool
  default     = false
}

variable "actions_allowed_actions_config" {
  description = "Only used when actions_allowed_actions = \"selected\"."
  type = object({
    github_owned_allowed = optional(bool, true)
    verified_allowed     = optional(bool, true)
    patterns_allowed     = optional(list(string), [])
  })
  default = {}
}

# --- Paid-plan gate ----------------------------------------------------------
# Master switch for features that require a paid GitHub plan (Team or higher).
# While false, the settings below are written but NOT applied (no API call, so
# no 403). Flip to true once the org is upgraded and the same config activates.
variable "paid_plan_features_enabled" {
  description = "Enable features that require a paid GitHub plan (e.g. org rulesets)."
  type        = bool
  default     = false
}

# --- Org-wide branch/tag rulesets (PAID: requires GitHub Team plan) ----------
# Gated by var.paid_plan_features_enabled. On Free the rulesets API returns 403.
variable "organization_rulesets" {
  description = "Org-wide rulesets keyed by ruleset name. Empty = none (no API call)."
  type = map(object({
    enforcement   = optional(string, "active") # active | evaluate | disabled
    target        = optional(string, "branch") # branch | tag
    include_refs  = optional(list(string), ["~DEFAULT_BRANCH"])
    exclude_refs  = optional(list(string), [])
    include_repos = optional(list(string), ["~ALL"])
    exclude_repos = optional(list(string), [])

    require_pull_request            = optional(bool, true)
    required_approving_reviews      = optional(number, 0)
    require_code_owner_review       = optional(bool, false)
    dismiss_stale_reviews_on_push   = optional(bool, true)
    require_conversation_resolution = optional(bool, true)
    required_status_checks          = optional(list(string), [])

    block_force_push       = optional(bool, true) # non_fast_forward
    block_deletion         = optional(bool, true)
    block_creation         = optional(bool, false)
    require_linear_history = optional(bool, false)
    require_signatures     = optional(bool, false)
    bypass_org_admins      = optional(bool, true)
  }))
  default = {}
}

variable "teams" {
  description = "Teams managed by Terraform, keyed by team name. Org-level; repo access grants are intentionally out of scope."
  type = map(object({
    description = optional(string, "")
    privacy     = optional(string, "closed") # closed | secret
    members     = optional(map(string), {})  # username => "member" | "maintainer"
  }))
  default = {}
}
