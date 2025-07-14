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

## Collecting Logs with OpenTelemetry

Install the OpenTelemetry SDK and exporter packages in your application environment:

```bash
pip install opentelemetry-sdk opentelemetry-exporter-otlp opentelemetry-instrumentation-fastapi
```

The `app.py` file configures a `LoggerProvider` with an OTLP exporter. The environment variable `OTEL_EXPORTER_OTLP_ENDPOINT` should point to the OpenTelemetry Collector service. Logs produced using the standard `logging` module are automatically sent to the collector via the `LoggingHandler`:

```python
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import OTLPLogExporter, BatchLogRecordProcessor

log_provider = LoggerProvider()
log_exporter = OTLPLogExporter(endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT"))
log_provider.add_log_record_processor(BatchLogRecordProcessor(log_exporter))
handler = LoggingHandler(level=logging.INFO, logger_provider=log_provider)
logger = logging.getLogger("test_app")
logger.addHandler(handler)
```

With this setup, any calls to `logger.info()` will appear in your configured log backend via the collector.
