SHELL       := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help init plan apply destroy fmt validate clean get-kubeconfig port-forward

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / { printf "  %-10s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

init: ## Initialize Terraform (downloads providers, modules)
	cd infra && terraform init -upgrade

plan: ## Show Terraform plan
	cd infra && terraform plan

apply: ## Apply Terraform changes
	cd infra && terraform apply -auto-approve

fmt: ## Format Terraform code
	cd infra && terraform fmt -recursive

validate: ## Validate Terraform code
	cd infra && terraform validate

destroy: ## Destroy Terraform-managed infrastructure
	cd infra && terraform destroy -auto-approve
	$(MAKE) clean

clean: ## Remove local Terraform state & cache
	cd infra && rm -rf .terraform
	cd infra && rm -f terraform.tfstate* .terraform.lock.hcl

get-kubeconfig: ## Get kubeconfig for EKS cluster
	@if [ -f kubeconfig ]; then \
		rm -f kubeconfig; \
	fi
	touch kubeconfig
	aws eks update-kubeconfig --name my-cluster --kubeconfig kubeconfig --region us-east-1 --alias ${CLUSTER1}

kill-port-forwards: ## Kill processes running on ports 3000, 9090, and 8080
	@echo "Killing processes on ports 3000, 9090, and 8080..."
	-@for port in 3000 9090 8080; do \
		PID=$$(lsof -ti tcp:$$port); \
		if [ -n "$$PID" ]; then \
			kill -9 $$PID && echo "Killed process on port $$port (PID: $$PID)"; \
		else \
			echo "No process found on port $$port"; \
		fi \
	done

port-forward: get-kubeconfig kill-port-forwards ## Port-forward Grafana, Kiali, Prometheus, ArgoCD and print endpoints
	@echo "Starting port-forwards..."
	kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80 & \
	kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090 & \
	kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443 & \
	sleep 3; \
	echo "Grafana:      http://localhost:3000"; \
	echo "Prometheus:   http://localhost:9090"; \
	echo "ArgoCD:       http://localhost:8080";