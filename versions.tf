terraform {
  required_version = ">= 1.6"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  # State handling: terraform.tfstate is COMMITTED to this repo by design (see
  # README "State"). This org-level state was verified to hold no secret values
  # — no tokens, no provider-sensitive attributes — and CI is the sole writer.
  # A CI tripwire refuses to commit state if a sensitive attribute ever appears.
  #
  # If you add a resource whose state DOES store a secret, stop committing state
  # and switch to an encrypted remote backend (and gitignore terraform.tfstate),
  # e.g.:
  #
  # backend "s3" {
  #   bucket         = "chloros-nl-tfstate"
  #   key            = "github/terraform.tfstate"
  #   region         = "eu-west-1"
  #   dynamodb_table = "chloros-nl-tflock"
  #   encrypt        = true
  # }
}
