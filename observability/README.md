# Observability Cluster

This folder contains Terraform and Argo CD manifests used to deploy a small EKS cluster for experimenting with logging, monitoring and tracing tools. The infrastructure provisions Istio and uses Argo CD to manage a collection of Grafana applications.

## Infrastructure

The cluster is created through Terraform in [`infra`](./infra). A sample of the configuration shows the EKS module and Istio base release:

```hcl
module "cluster" {
  source = "../../modules/eks"
  name     = var.cluster_name
  vpc_cidr = "10.1.0.0/16"
  desired_nodes = 6
  max_nodes = 6
}

resource "helm_release" "istio_base" {
  depends_on       = [module.cluster]
  chart            = "base"
  version          = "1.25.1"
  name             = "istio-base"
  namespace        = "istio-system"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  create_namespace = true
}
```

Argo CD itself is installed via Terraform and then bootstraps the rest of the stack using an "app of apps" pattern:

```hcl
resource "argocd_application" "app_of_apps" {
  depends_on = [helm_release.argocd]
  metadata {
    name      = "observability"
    namespace = "argocd"
  }
  spec {
    project = "default"
    source {
      repo_url        = var.git_argocd_repo_url
      path            = "observability/argo/apps"
      target_revision = "HEAD"
    }
    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "observability"
    }
    sync_policy {
      automated {
        prune     = true
        self_heal = true
      }
    }
  }
}
```

## Applications managed by Argo CD

The `argo/apps` directory contains one Argo CD `Application` for each component. Examples include:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kube-prometheus-stack
  namespace: argocd
spec:
  project: default
  sources:
    - repoURL: https://github.com/henrypham67/istio
      targetRevision: HEAD
      path: observability/argo/values/kube-prometheus-stack
      ref: custom
    - repoURL: https://prometheus-community.github.io/helm-charts
      chart: kube-prometheus-stack
      targetRevision: 72.1.0
      helm:
        valueFiles:
          - $custom/observability/argo/values/kube-prometheus-stack/values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
```

Other applications follow the same pattern, for example Loki and the OpenTelemetry Operator:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: loki
  namespace: argocd
spec:
  project: default
  sources:
    - repoURL: https://grafana.github.io/helm-charts
      chart: loki
      targetRevision: 6.29.0
      helm:
        valueFiles:
          - $custom/observability/argo/values/loki.yaml
    - repoURL: https://github.com/henrypham67/istio
      targetRevision: HEAD
      ref: custom
  destination:
    server: https://kubernetes.default.svc
    namespace: logging
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: open-telemetry
  namespace: argocd
spec:
  project: default
  sources:
    - repoURL: https://open-telemetry.github.io/opentelemetry-helm-charts
      chart: opentelemetry-operator
      targetRevision: 0.90.4
    - repoURL: https://github.com/henrypham67/istio
      targetRevision: HEAD
      path: observability/argo/values/open-telemetry
  destination:
    server: https://kubernetes.default.svc
    namespace: opentelemetry-operator-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Collector configuration

The OpenTelemetry Collector forwards logs to Loki and traces to Tempo:

```yaml
exporters:
  otlphttp/loki:
    endpoint: http://loki-gateway.logging.svc.cluster.local/otlp
  otlphttp/tempo:
    endpoint: http://tempo.monitoring.svc.cluster.local:4318
service:
  pipelines:
    logs:
      receivers:
        - otlp
      processors:
        - batch
      exporters:
        - otlphttp/loki
    traces:
      receivers:
        - otlp
      processors:
        - batch
      exporters:
        - otlphttp/tempo
```

## Purpose

This environment brings together Prometheus, Loki, Tempo and other tools so that I can experiment with end-to-end observability on Kubernetes. It is not intended for production but as a sandbox for learning how these systems fit together.

