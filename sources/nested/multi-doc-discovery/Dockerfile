# Multi-Document Discovery Lambda Container Image
# Contains: scikit-learn, scipy, numpy, strands-agents, jinja2, Pillow, pypdfium2
# These dependencies exceed Lambda's 250MB unzipped layer limit, so we use container packaging.

FROM public.ecr.aws/lambda/python:3.12 AS builder

# Install build dependencies
RUN dnf install -y gcc gcc-c++ make && dnf clean all

# Install Python dependencies into /opt/python so we can copy them cleanly
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --target /opt/python -r /tmp/requirements.txt

# Install idp_common package
COPY lib/idp_common_pkg /tmp/idp_common_pkg
RUN pip install --no-cache-dir --no-deps --target /opt/python /tmp/idp_common_pkg

# --- Final stage ---
FROM public.ecr.aws/lambda/python:3.12

# Copy installed packages from builder
COPY --from=builder /opt/python ${LAMBDA_TASK_ROOT}/../opt/python

# Add /var/task/../opt/python to PYTHONPATH so Lambda can find the packages
ENV PYTHONPATH="${LAMBDA_TASK_ROOT}/../opt/python:${LAMBDA_TASK_ROOT}"

# Copy Lambda handler code
COPY src/lambda/multi_doc_discovery/*.py ${LAMBDA_TASK_ROOT}/

# Default handler - overridden per function via ImageConfig.Command
CMD ["embed_handler.handler"]
