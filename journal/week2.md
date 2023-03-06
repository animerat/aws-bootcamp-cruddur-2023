# Week 2 — Distributed Tracing

## Required Homework

### Getting HoneyComb Configured

Add the opentelemetry libraries to our python environment

```
opentelemetry-api 
opentelemetry-sdk 
opentelemetry-exporter-otlp-proto-http 
opentelemetry-instrumentation-flask 
opentelemetry-instrumentation-requests
```

From a python terminal install the new opentelemetry libraries
```
pip install -r requirements.txt
```

Within the **app.py** script, import Opentelemtry functions:

```python
from opentelemetry import trace
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
```

Within the **app.py** script, initialize tracing and exporter to send data to Honeycomb:
```python
provider = TracerProvider()
processor = BatchSpanProcessor(OTLPSpanExporter())
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)
```

Within the **app.py** script, initialize instrumentation with Flask:
```python
app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()
```

Add environment variables to the backend-flask container in docker compose:
```Dockerfile
OTEL_EXPORTER_OTLP_ENDPOINT: "https://api.honeycomb.io"
OTEL_EXPORTER_OTLP_HEADERS: "x-honeycomb-team=${HONEYCOMB_API_KEY}"
OTEL_SERVICE_NAME: "${HONEYCOMB_SERVICE_NAME}"
```

Configure personal account API keys into gitpod environment:
```
export HONEYCOMB_API_KEY=""
export HONEYCOMB_SERVICE_NAME="Cruddur"
gp env HONEYCOMB_API_KEY=""
gp env HONEYCOMB_SERVICE_NAME="Cruddur"
```

#### Results from HoneyComb Dashboard
![Image of HoneyComb_Dashboard](assests/2_Week_HoneyComb_Dashboard.png)

#### Results from HoneyComb Traces
![Image of HoneyComb_Traces](assests/2_Week_HoneyComb_Traces.png)


