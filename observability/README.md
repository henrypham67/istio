# Observability Cluster

This folder contains Terraform and Argo CD manifests used to deploy a small EKS cluster for experimenting with logging, monitoring and tracing tools. The infrastructure provisions Istio and uses Argo CD to manage a collection of Grafana applications.

```text
└── observability
    ├── README.md
    ├── argo
        ├── apps
        │   ├── keda.yaml
        │   ├── kiali.yaml
        │   ├── kube-prometheus-stack.yaml
        │   ├── loki.yaml
        │   ├── mimir.yaml
        │   ├── open-telemetry.yaml
        │   ├── tempo.yaml
        │   └── test-app.yaml
        └── values
        │   ├── keda.yaml
        │   ├── kiali.yaml
        │   ├── kibana.yaml
        │   ├── kube-prometheus-stack
        │       ├── dashboards
        │       │   ├── istio_control_plane.json
        │       │   └── istio_loki.json
        │       ├── kustomization.yaml
        │       ├── values.yaml
        │       └── virtual-service.yaml
        │   ├── loki.yaml
        │   ├── mimir.yaml
        │   ├── open-telemetry
        │       └── collector.yaml
        │   ├── tempo.yaml
        │   └── test-app
        │       ├── deploy.yaml
        │       ├── kustomization.yaml
        │       ├── service-monitor.yaml
        │       ├── service.yaml
        │       └── virtual-service.yaml
    ├── infra
        ├── Makefile
        ├── argocd.tf
        ├── main.tf
        ├── mimir.tf
        ├── providers.tf
        ├── values
        │   ├── argocd.yaml
        │   └── istio.yaml
        ├── variables.tf
        └── versions.tf
    └── test-app
        ├── Dockerfile
        ├── app.py
        └── requirements.txt
```
---

## Components

### 1. Metrics

- **Prometheus** (via the **kube-prometheus-stack** Helm chart)
  - Scrapes Kubernetes metrics (node, pod, service) and Istio telemetry via `ServiceMonitor` objects.
  - Remote-writes long-term storage into **Mimir** to offload local TSDB.  
- **Mimir** (Grafana Mimir Distributed)
  - Acts as a horizontally scalable, multi-tenant remote write store.
  - Receives Prometheus’ remote write streams and persists blocks to S3.
- **Grafana**
  - Sidecar injects dashboards for Istio control plane and Loki.
  - Configured with two data sources:
    - Prometheus (via kube-prometheus-stack)
    - Loki (Logs)
    - Tempo (Traces)

### 2. Logs

- **OpenTelemetry Collector**
  - Receives logs via OTLP HTTP/gRPC and file-log receiver.
  - Batches and exports to **Loki** (Grafana Loki) and `debug` (local logging).
- **Loki**
  - Indexed, cost-effective log store; integrates tightly with Grafana.
  - Schema and storage defined in `loki.yaml` (TSDB backend with filesystem).

### 3. Tracing

- **OpenTelemetry Collector**
  - Receives spans via OTLP.
  - Batches and forwards to **Tempo** (Grafana Tempo).
- **Tempo**
  - Agentless, highly scalable trace store.
  - Generates its own metrics (via `metricsGenerator`) and remote-writes them to Mimir for end-to-end metrics in Grafana.

### 4. Service Mesh Visualization

- **Istio**  
  - Provides Envoy-based service mesh instrumentation:
    - Metrics (`envoy_*`) scraped by Prometheus.
    - Logs (access logs) parsed by OpenTelemetry Collector.
  - **Kiali**  
    - Installed in `istio-system` to visualize mesh topology, metrics, and traces.

### 5. Autoscaling

- **KEDA** (Kubernetes Event-Driven Autoscaling)
  - Operator and Metrics Adapter run with Istio sidecar exclusions.
  - Scales workloads based on Prometheus metrics via a `ScaledObject` (not shown here).

---

## Deployment

1. **Bootstrap cluster & Istio**  
   `infra/` contains Terraform code to provision:
   - EKS cluster
   - Istio base, control plane, and ingress gateway
   - Argo CD server, gateway, and "app-of-apps" application

2. **GitOps with Argo CD**  
   - The `argocd_application.app_of_apps` in Terraform targets `observability/argo/apps/`.
   - Each sub-directory (e.g. `kube-prometheus-stack`, `loki`, `open-telemetry`, etc.) contains an Argo CD `Application` manifest to sync that component.

3. **Custom Values**  
   - All Helm value overrides live under `observability/argo/values/`.
   - Includes dashboards, sidecar datasources, pipeline configs, and Istio annotations.

4. **Test Application**  
   - `observability/test-app` runs a FastAPI service:
     - Instrumented with OpenTelemetry for traces and logs.
     - Exposes Prometheus metrics on `/metrics`.
     - Demonstrates the full pipeline: app → collector → Loki/Tempo/Prometheus → Grafana.

---

## How It Works

1. **Instrumentation**  
   - Services (Istio proxies, test-app) generate metrics, logs, and traces.
2. **Collection & Aggregation**  
   - **OpenTelemetry Collector** centralizes logs & traces and forwards to Loki/Tempo.
   - **Prometheus** scrapes metrics and remote-writes to Mimir.
3. **Storage**  
   - **Loki** stores logs, optimized for high-volume unstructured data.
   - **Tempo** stores traces in object storage/backed by index-free design.
   - **Mimir** stores metrics blocks in S3, providing long-term retention.
4. **Visualization**  
   - **Grafana** dashboards present:
     - Control plane health (Istio dashboards)
     - Log search and streams (Loki dashboards)
     - Trace queries and flame graphs (Tempo integration)
     - Application metrics (Prometheus + Mimir)

---

## Getting Started

```bash
# Bootstrap infra
cd observability/infra
make init
make apply

# Sync Argo CD apps
# (Argo CD server UI available via Istio gateway on port 80)
```

## AWS CLI Commands

### List All Network Load Balancers

To list all Network Load Balancers in your AWS account, use the following AWS CLI command:

```bash
aws elbv2 describe-load-balancers --query 'LoadBalancers[?Type==`network`]'
```

This command:
- Uses the `elbv2` service (Elastic Load Balancing v2)
- Retrieves all load balancers with `describe-load-balancers`
- Filters the results with a JMESPath query to show only Network Load Balancers (`Type==network`)

For a more concise output showing only the names and DNS names:

```bash
aws elbv2 describe-load-balancers --query 'LoadBalancers[?Type==`network`].[LoadBalancerName,DNSName]' --output table
```

To filter by a specific region:

```bash
aws elbv2 describe-load-balancers --region us-west-2 --query 'LoadBalancers[?Type==`network`]'
```

## References
- https://devopsvoyager.hashnode.dev/full-opentelemetry-setup-for-metrics-logs-and-traces-in-kubernetes

Here are some ideas to tighten up, harden, and streamline your observability sandbox:

---

1. Infrastructure as Code (Terraform)
- Remote state & locking
Move your Terraform state into a remote backend (e.g. S3 + DynamoDB for locking) rather than local files. This will let multiple collaborators safely work on infra and avoid “state drift” mistakes.
- Module reuse & consistency
You’re already using an EKS module for the cluster; consider extracting common pieces (e.g. Argocd installation, Istio base/gateway) into your own shared modules. That reduces copy-pasted HCL and makes upgrades across environments easier.
- Version pinning & upgrades
- Pin your Terraform provider versions (you do this in versions.tf, which is great) and periodically run terraform init -upgrade + terraform plan to see available updates.
- Likewise, for Helm charts (Istio 1.25.1, KEDA 2.17.1, Tempo 1.21.1, etc.), define a “chart-versions.yaml” in your repo’s root so you can bump all charts in one place and track which versions you’re running.
- Automated linting & validation
Integrate tflint, terraform fmt -recursive and terraform validate into your CI pipeline (GitHub Actions/GitLab CI). This catches syntax errors, best-practice violations, and drift before you apply.

---

2. GitOps & Argo CD
- App-of-Apps structure
Instead of pointing every child Application at the same repo path, group by functional areas or namespaces:
```
observability/argo/apps/
  ├── logging/
  │   ├── loki.yaml
  │   └── mimir.yaml
  ├── metrics/
  │   └── kube-prometheus-stack.yaml
  └── tracing/
      ├── tempo.yaml
      └── open-telemetry.yaml
```

This makes it easier to pause or roll back one area without touching others.
- Projects & RBAC
Define Argo CD Projects (e.g. “observability-logging”, “observability-metrics”) with scoped destinations and source repos. You can then grant finer-grained permissions to teams and prevent “cross-namespace” deploys.
- Sync Waves & Hooks
Some charts have dependencies (e.g. you want PrometheusCRDs created before Prometheus Operator). Use syncPolicy.syncWaves or pre-sync hooks to enforce ordering, or move CRD installation into Terraform so Argo CD doesn’t race on CRDs.
- Health Checks & Rollbacks
For each Application, set a custom health.lua or leverage built-in health checks for CRDs so Argo CD can detect “unhealthy” and auto-rollback if something goes wrong.

---

3. Observability Stack Enhancements

High-Availability & Persistence
- Loki: consider the Boltdb Shipper + object store instead of filesystem TSDB so you can scale out and survive node restarts.
- Mimir: enable multi-AZ S3 bucket + compactor & store-gateway replication for durability.
- Prometheus: deploy at least two replicas and remote-write to Mimir (you already do this!), but also configure read-through caching or Thanos sidecar if you need long-term retention.
- Security & Encryption
- TLS-encrypt all internal traffic (mTLS via Istio is already in place, but ensure OTLP/gRPC and Loki ingest endpoints are TLS).
- Enable authentication on Loki & Mimir Grafana DataSources (e.g. use basicAuth or bearer tokens).
- Store sensitive values (e.g. Argo CD admin password, S3 credentials) in sealed-secrets or HashiCorp Vault, not in plain YAML.
- Resource requests, limits & autoscaling 
- Add resources.requests/limits for all workloads (you have them in Loki, but e.g. Tempo, Collector, KEDA, Kiali, test-app lack them). Then use Horizontal Pod Autoscalers for load-driven scaling.
- Alerting & SLOs
- Define critical alerting rules in your Prometheus values (e.g. PrometheusRule for high error rates, high latency, disk pressure on Loki/Mimir).
- Add Grafana SLO dashboards (e.g. via the Grafana SLO operator) so you can target reliability goals even in a sandbox.
- Dashboards & Metrics Cleanup
- Consider splitting super-long Grafana dashboards into focused “Service Mesh Overview” vs “Envoy Proxy Metrics” vs “Control Plane Metrics”.
- Use Grafana’s folder structure (via sidecar config) to group dashboards by namespace or functional area.

---

4. Test App & OpenTelemetry
- Instrumentation Edge Cases
- Add a /healthz endpoint and Liveness/Readiness probes so Kubernetes knows when the app is truly up.
- Disable randomness in test-app’s sleep during load testing by parameter (so you can get consistent latency curves).
- BatchSpanProcessor tuning
The default BatchSpanProcessor flushing settings may delay spans. Tune scheduleDelayMillis or use the OTLP exporter’s compression to lower overhead.
- Logs vs Traces vs Metrics separation
Consider splitting exporters (e.g. a dedicated log and trace pipeline) so you can route logs to Loki with filtering (e.g. drop DEBUG-level logs).

---

5. Security & Compliance
- Pod Security Policies / PSP Replacement
Enforce a restrictive PodSecurity (or PodSecurityAdmission) policy so only certain namespaces can run privileged workloads.
- NetworkPolicy
Use Calico or Istio AuthorizationPolicies to lock down pod-to-pod traffic by label, not “allow all” in a mesh.
- Container Scanning
Integrate a scanner (Trivy, Clair) in your CI for Dockerfiles (e.g. test-app), and fail on high severity.

---

6. Documentation & Onboarding
- Enhanced README
- Capture the folder structure, explain each directory’s purpose at a glance.
- Examples & Recipes
Include “recipes” in docs for common tasks: how to add a new application to Argo CD, how to write a ServiceMonitor, or how to extend your test-app with a custom metric.
- Version Matrix
Maintain a simple table in your README with each component’s chart version vs tested Kubernetes / Istio version, so you know what combos are supported.
