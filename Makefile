.PHONY: help init fmt validate plan apply import-org import-actions check

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

init: ## Initialize providers + backend
	terraform init

fmt: ## Format .tf files
	terraform fmt -recursive

validate: ## Validate configuration
	terraform validate

check: fmt validate ## Format + validate

plan: ## Show planned changes
	terraform plan

apply: ## Apply changes (break-glass only — normally CI applies on merge to main)
	terraform apply

import-org: ## Import the existing org settings (run once). Needs admin:org token.
	terraform import github_organization_settings.this $$(gh api orgs/chloros-nl --jq .id)

import-actions: ## Import org Actions permissions (run once)
	terraform import github_actions_organization_permissions.this chloros-nl
