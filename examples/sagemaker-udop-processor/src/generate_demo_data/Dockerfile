FROM public.ecr.aws/lambda/python:3.11

# Copy requirements file
COPY requirements.txt ${LAMBDA_TASK_ROOT}

# Install the specified packages
RUN pip install -r requirements.txt

# Copy function code
COPY index.py ${LAMBDA_TASK_ROOT}

# Create writable directories in /tmp
RUN mkdir -p /tmp/huggingface /tmp/transformers /tmp/datasets /tmp/torch /tmp/cache /tmp/hf_hub_cache

# Set the CMD to your handler (this is the correct format for Lambda container images)
CMD [ "index.lambda_handler" ]
