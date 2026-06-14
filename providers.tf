provider "github" {
  owner = var.github_owner

  # Auth comes from the environment, never hardcoded:
  #   export GITHUB_TOKEN=<token>
  #
  # The token needs admin:org + repo + workflow scopes (PAT), or an
  # equivalent GitHub App installation token. Read the README for which
  # auth to use and why an App token is preferred for CI.
}
