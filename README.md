# Multi-Cluster Istio Patterns

This repository provides Terraform configurations for deploying multi-cluster Istio on AWS using various networking and certificate management patterns.

## 📁 Available Patterns

- [`internet`](patterns/internet): Cross-cluster communication over **internet-facing gateways**.
- [`peering`](patterns/peering): Communication via **AWS VPC peering**.
- [`peering-cert-manager`](patterns/peering-cert-manager): VPC peering with **Vault + cert-manager**-based certificate management.

---

## 🔧 Prerequisites

- [Terraform >= 1.3](https://developer.hashicorp.com/terraform)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)
- AWS credentials (via `aws configure` or environment variables)

---

## 🚀 Usage

Each pattern folder includes a `Makefile` to simplify usage.

### Common Make Targets

```bash
make init        # Initialize Terraform
make plan        # Show Terraform plan
make apply       # Apply infrastructure
make destroy     # Tear down resources
make validate    # Validate configuration
make fmt         # Format Terraform code
make check-sync  # Verify cross-cluster connectivity (if supported)
```

## 📦 Pattern-Specific Instructions

patterns/internet

Uses internet-facing Istio east-west gateways with self-managed CA.

cd patterns/internet
make apply

patterns/peering

Sets up private east-west communication using AWS VPC peering.

cd patterns/peering
make apply

patterns/peering-cert-manager

Uses Vault and cert-manager to issue Istio certificates.

cd patterns/peering-cert-manager
bash scripts/deploy.sh

This script bootstraps the infrastructure and configures Vault.

## ✅ Post-Deployment Check

Run the sync script to validate application connectivity across clusters:

```bash
make check-sync
```

## 📎 Notes

- Each cluster deploys a sample helloworld and sleep app.
- Secrets, remote Kubeconfigs, and gateways are auto-managed by Terraform and Helm.
