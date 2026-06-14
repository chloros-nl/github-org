terraform {
  required_version = ">= 1.6"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  # Local state by default. For team use, switch to a remote backend so state
  # is shared and locked. Example (uncomment + configure):
  #
  # backend "s3" {
  #   bucket         = "chloros-nl-tfstate"
  #   key            = "github/terraform.tfstate"
  #   region         = "eu-west-1"
  #   dynamodb_table = "chloros-nl-tflock"
  #   encrypt        = true
  # }
  #
  # State contains secret *values* you set via Terraform. Keep it out of git
  # (see .gitignore) and prefer an encrypted remote backend.
}
