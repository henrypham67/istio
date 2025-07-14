import logging
import os
import random
import time

from fastapi import FastAPI
from fastapi.responses import Response
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk._logs import LoggerProvider
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry._logs import set_logger_provider
from opentelemetry.sdk._logs import LoggingHandler
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter

# Configure tracing
resource = Resource.create({"service.name": "observability-test-app"})
tracer_provider = TracerProvider(resource=resource)
span_exporter = OTLPSpanExporter(
    endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://opentelemetry-collector.opentelemetry-operator-system.svc.cluster.local:4317"),
    insecure=True,
)
tracer_provider.add_span_processor(BatchSpanProcessor(span_exporter))
trace.set_tracer_provider(tracer_provider)
tracer = trace.get_tracer(__name__)

# Configure logging
log_provider = LoggerProvider(resource=resource)
log_exporter = OTLPLogExporter(
    endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://opentelemetry-collector.opentelemetry-operator-system.svc.cluster.local:4317"),
    insecure=True,
)
log_provider.add_log_record_processor(BatchLogRecordProcessor(log_exporter))
set_logger_provider(log_provider)
handler = LoggingHandler(level=logging.INFO, logger_provider=log_provider)
logger = logging.getLogger("test_app")
logger.setLevel(logging.INFO)
logger.addHandler(handler)

# Prometheus metric
REQUEST_COUNT = Counter("test_app_requests_total", "Number of requests")

app = FastAPI()
FastAPIInstrumentor().instrument_app(app)

@app.get("/")
async def read_root():
    REQUEST_COUNT.inc()
    logger.info("handling request")
    with tracer.start_as_current_span("process_request"):
        time.sleep(random.uniform(0.1, 0.5))
    return {"message": "Hello from observability test app"}

@app.get("/metrics")
async def metrics():
    data = generate_latest()
    logger.info("printing metrics")
    return Response(content=data, media_type=CONTENT_TYPE_LATEST)
