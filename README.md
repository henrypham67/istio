# Multi-Cluster Istio Patterns

This repository provides Terraform configurations for deploying multi-cluster Istio on AWS using various networking and certificate management patterns.

## 📁 Available Patterns

- [`internet`](multi-network/internet): Cross-cluster communication over **internet-facing gateways**.
- [`peering`](multi-network/peering): Communication via **AWS VPC peering**.
- [`peering-cert-manager`](multi-network/peering-cert-manager): VPC peering with **Vault + cert-manager**-based certificate management.

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

### internet

Uses internet-facing Istio east-west gateways with self-managed CA.

```bash
cd multi-network/internet
make init apply
```

### peering

Sets up private east-west communication using AWS VPC peering.

```bash
cd multi-network/peering
make init apply
```

### peering-cert-manager

Uses Vault and cert-manager to issue Istio certificates.

```bash
cd multi-network/peering-cert-manager
make deploy
```

This script bootstraps the infrastructure and configures Vault.

## ✅ Post-Deployment Check

Run the sync script to validate application connectivity across clusters:

```bash
make check-sync
```

## 📎 Notes

- Each cluster deploys a sample helloworld and sleep app.
- Secrets, remote Kubeconfigs, and gateways are auto-managed by Terraform and Helm.
