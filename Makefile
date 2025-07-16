SHELL := /bin/bash

.PHONY: lint lint-terraform lint-yaml

lint: lint-terraform lint-yaml

lint-terraform:
	@terraform -chdir=observability/infra fmt -check -recursive
	@terraform -chdir=observability/infra validate

lint-yaml:
	@yamllint -s observability/argo || true
