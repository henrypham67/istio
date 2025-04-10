# Learn Istio

Code from this repository is inspired a lot by [istio-on-eks](https://github.com/aws-samples/istio-on-eks)

## Multi-primary & Multi-network over internet

Uncomment `main.tf` file at root project to enable this pattern
To deploy infrastructure and application for testing
```bash
make init apply
```

To check connection
```bash
./scripts/check-cross-cluster-sync.sh
```