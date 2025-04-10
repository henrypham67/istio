# Learn Istio

Code from this repository is inspired a lot by [istio-on-eks](https://github.com/aws-samples/istio-on-eks)

## Multi-primary & Multi-network over internet

Update `.envrc` file to enable this pattern
```bash
export TF_VAR_ENABLE_MULTI_PRIMARY_INTERNET=1
```

To deploy infrastructure and application for testing
```bash
make init apply
```

To check connection
```bash
./scripts/check-cross-cluster-sync.sh
```