# Variables
SHELL := /bin/bash
.DEFAULT_GOAL := help

# Terraform variables
TF_VAR_FILE ?= terraform.tfvars
WORKSPACE ?= default

.PHONY: help
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: init
init: ## Initialize Terraform
	terraform init -upgrade

.PHONY: plan
plan: ## Show Terraform plan
	terraform plan

.PHONY: apply
apply: ## Apply Terraform changes
	terraform apply -auto-approve

.PHONY: destroy
destroy: ## Destroy Terraform-managed infrastructure
	terraform destroy -auto-approve

.PHONY: fmt
fmt: ## Format Terraform code
	terraform fmt -recursive

.PHONY: validate
validate: ## Validate Terraform code
	terraform validate

.PHONY: workspace
workspace: ## Create or switch to a workspace
	terraform workspace select $(WORKSPACE) || terraform workspace new $(WORKSPACE)

.PHONY: clean
clean: ## Clean Terraform files
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*

.PHONY: get-kubeconfig
get-kubeconfig: ## Get kubeconfig for EKS cluster
	@if [ -f kubeconfig ]; then \
		rm -f kubeconfig; \
	fi
	touch kubeconfig
	aws eks update-kubeconfig --name ${CLUSTER1} --kubeconfig kubeconfig --region us-east-1
	aws eks update-kubeconfig --name ${CLUSTER2} --kubeconfig kubeconfig --region us-west-2

.PHONY: all
all: init validate plan apply ## Run init, validate, plan, and apply

.PHONY: lint
lint: ## Run Terraform lint
	terraform fmt -check
	terraform validate

.PHONY: output
output: ## Show Terraform outputs
	terraform output

.PHONY: state-list
state-list: ## List resources in Terraform state
	terraform state list

.PHONY: refresh
refresh: ## Refresh Terraform state
	terraform refresh

.PHONY: create-key-pairs
create-key-pairs:
	@{ \
		if ! command -v aws &> /dev/null; then \
			echo "Error: AWS CLI is not installed." >&2; \
			exit 1; \
		fi; \
		if ! command -v jq &> /dev/null; then \
			echo "Error: jq is not installed." >&2; \
			exit 1; \
		fi; \
		if [ -f default.pem ]; then \
			rm -f default.pem; \
		fi; \
		aws ec2 create-key-pair --key-name default --output json | jq .KeyMaterial -r > default.pem; \
		chmod 400 default.pem; \
	}

ssh:
	ssh -i ${CLUSTER_SSH_KEY} ec2-user@<NODE_IP> \
    -o "ProxyCommand ssh -W %h:%p -i ${CLUSTER_SSH_KEY} ubuntu@${BASTION_HOST}"
