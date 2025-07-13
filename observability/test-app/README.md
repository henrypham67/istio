# Observability Test Application

This sample FastAPI service emits traces, logs and Prometheus metrics so you can verify your observability stack.

## Build the container

```bash
docker build -t your-registry/test-app:latest .
```

Push the image to a registry accessible by your cluster, then deploy the manifest.

## Deploy to Kubernetes

```bash
kubectl apply -f k8s.yaml
```

The deployment uses environment variables so the OpenTelemetry SDK sends data to the collector installed in the `monitoring` namespace.

## Endpoints

- `/` simple HTTP endpoint that generates traces and logs
- `/metrics` Prometheus metrics endpoint
