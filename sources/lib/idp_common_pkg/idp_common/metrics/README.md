Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

# Metrics Module

The Metrics module provides performance tracking and CloudWatch metrics publishing for the IDP pipeline.

## Public Functions

| Function | Description |
|----------|-------------|
| `publish_metric(metric_name, value, unit, dimensions)` | Publish a custom metric to CloudWatch |
| `record_duration(metric_name, start_time, dimensions)` | Record elapsed time as a CloudWatch metric |

## Usage

### Publishing Metrics

```python
from idp_common.metrics import publish_metric

# Publish a custom metric
publish_metric(
    metric_name="DocumentsProcessed",
    value=1,
    unit="Count",
    dimensions={"DocumentType": "invoice"}
)
```

### Recording Duration

```python
import time
from idp_common.metrics import record_duration

start = time.time()
# ... processing ...
record_duration(
    metric_name="ExtractionDuration",
    start_time=start,
    dimensions={"Step": "extraction"}
)
```

## Environment Variables

- `METRICS_NAMESPACE`: CloudWatch namespace for metrics (default: `IDP`)
- `ENABLE_METRICS`: Set to `false` to disable metric publishing
