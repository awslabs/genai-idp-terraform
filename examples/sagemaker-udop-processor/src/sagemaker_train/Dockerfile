FROM public.ecr.aws/lambda/python:3.11

# Copy requirements file
COPY requirements.txt ${LAMBDA_TASK_ROOT}

# Install the specified packages
RUN pip install -r requirements.txt

# Copy function code
COPY index.py ${LAMBDA_TASK_ROOT}
RUN mkdir -p ${LAMBDA_TASK_ROOT}/code
COPY code/* ${LAMBDA_TASK_ROOT}/code/.

# Create writable directories in /tmp
RUN mkdir -p /tmp/sagemaker /tmp/cache

# Set the CMD to your handler
CMD [ "index.lambda_handler" ]
