# External MCP Client Example

This example demonstrates how to connect to the IDP MCP Server from an external application using Python.

## Overview

The document processor example shows how to:
- Authenticate with Cognito using user credentials
- Call MCP tools via the AgentCore Gateway
- Process PDF documents through the IDP system
- Poll for processing status and monitor progress

## Prerequisites

1. Python 3.12+
2. Required packages:
   ```bash
   pip install -r requirements.txt
   ```

3. Access to an IDP MCP Server deployment with:
   - MCP gateway endpoint URL
   - Cognito user pool credentials (client ID, secret, user pool ID)
   - User credentials (username, password)

## Configuration

Edit `mcp_client_config.properties` with your MCP server details:

### Configuration Properties

| Property | Description | Example |
|----------|-------------|---------|
| `mcp_endpoint` | MCP gateway endpoint URL | `https://mcp-gateway.../mcp` |
| `mcp_client_id` | Cognito OAuth 2.0 client ID | `1hlageim533mu6u2c6jse1fbtb` |
| `mcp_client_secret` | Cognito OAuth 2.0 client secret | `1kco8ernlu6b9dgbdgkqlh8o2ru1cqfd...` |
| `mcp_token_url` | Cognito token endpoint | `https://cognito-domain/oauth2/token` |
| `mcp_username` | Cognito user pool username | `user@example.com` |
| `mcp_password` | Cognito user pool password | `YourPassword123#` |
| `mcp_user_pool_id` | Cognito user pool ID | `us-east-1_rMNfafN5x` |
| `sample_pdf_path` | Path to PDF file to process | `./sample.pdf` |

### Security Notes

- **Never commit credentials** to version control
- Store sensitive values in environment variables or AWS Secrets Manager
- Use temporary credentials when possible
- Rotate credentials regularly

## Usage

Run the example:

```bash
python process_document.py
```

The script will:
1. Load configuration from `mcp_client_config.properties`
2. Authenticate with Cognito
3. Read and encode the sample PDF
4. Submit it for processing via the MCP server
5. Poll for status until processing completes

### Output Example

```
============================================================
MCP Client Example - PDF Processing
============================================================

[0] Authenticating with Cognito...
    Using user credentials for user@example.com
    Token obtained (length: 1234)
    Authentication successful

[1] Reading PDF: ./sample.pdf
    PDF size: 245.32 KB

[2] Sending process request...
    Calling tool: IDPTools___process
    Response status: 200
    Extracting result from response...
    Parsed MCP content text
    Parsed Lambda body
    Batch ID: mcp-content-20240115-143022
    Documents queued: 1

[3] Checking processing status...
    Progress: 0.0% | Completed: 0/1 | Failed: 0
    Progress: 50.0% | Completed: 0/1 | Failed: 0
    Progress: 100.0% | Completed: 1/1 | Failed: 0
    Processing complete!

============================================================
Processing completed successfully!
============================================================
```

## Code Structure

### DocumentProcessor Class

Handles authentication and MCP tool invocation:

```python
processor = DocumentProcessor(
    endpoint="https://your-mcp-gateway/mcp",
    client_id="your-client-id",
    client_secret="your-client-secret",
    token_url="https://your-cognito-domain/oauth2/token",
    username="your-username",
    password="your-password",
    user_pool_id="your-user-pool-id"
)

# Authenticate
if processor.authenticate():
    # Call tools
    result = processor.call_tool("process", {
        "content": base64_pdf,
        "name": "document.pdf"
    })
```

**Key Methods:**
- `authenticate()` - Get access token from Cognito
- `call_tool(tool_name, arguments)` - Call MCP tool via gateway
- `get_secret_hash(username)` - Compute SECRET_HASH for Cognito

### Helper Functions

- `load_config(config_path)` - Load configuration from properties file
- `extract_response_data(response)` - Extract result from nested MCP gateway response
- `process_pdf(processor, pdf_path)` - Submit PDF for processing
- `check_status(processor, batch_id)` - Poll batch status until completion

## Integration Patterns

### Basic Usage

```python
from process_document import DocumentProcessor, extract_response_data

# Create processor
processor = DocumentProcessor(
    endpoint="https://your-endpoint",
    client_id="your-id",
    client_secret="your-secret",
    token_url="https://your-token-url",
    username="your-username",
    password="your-password",
    user_pool_id="your-pool-id"
)

# Authenticate
if not processor.authenticate():
    raise Exception("Authentication failed")

# Process document
result = processor.call_tool("process", {
    "content": base64_pdf,
    "name": "doc.pdf"
})

# Extract result
data = extract_response_data(result)

if data.get("success"):
    batch_id = data["batch_id"]
    print(f"Processing batch: {batch_id}")
```

### Using Configuration File

```python
from process_document import DocumentProcessor, load_config
from pathlib import Path

# Load config
config = load_config("mcp_client_config.properties")

# Create processor
processor = DocumentProcessor(
    endpoint=config["mcp_endpoint"],
    client_id=config["mcp_client_id"],
    client_secret=config["mcp_client_secret"],
    token_url=config["mcp_token_url"],
    username=config["mcp_username"],
    password=config["mcp_password"],
    user_pool_id=config["mcp_user_pool_id"]
)
```

## Response Structure

The MCP gateway wraps responses in a nested structure:

```
MCP Gateway Response
├── result
│   └── content[0]
│       └── text (JSON string)
│           ├── statusCode (Lambda wrapper)
│           └── body (JSON string)
│               ├── success (boolean)
│               ├── batch_id (string)
│               ├── status (object)
│               └── progress (object)
```

The `extract_response_data()` function handles this unwrapping automatically.

## Error Handling

The processor handles:
- Authentication failures (invalid credentials)
- Network errors (connection timeouts)
- Invalid responses (malformed JSON)
- Missing configuration (file not found)

Check console output for detailed error messages.

## Troubleshooting

### Authentication Failed
- Verify Cognito credentials in config file
- Check user pool ID format: `region_poolid`
- Ensure user has access to the Cognito application

### Connection Timeout
- Verify MCP endpoint URL is correct
- Check network connectivity to the gateway
- Increase timeout values if needed

### PDF Not Found
- Verify `sample_pdf_path` is correct
- Use absolute path if relative path fails
- Check file permissions

### Processing Timeout
- Default timeout is 300 seconds (5 minutes)
- Increase `max_wait` parameter in `check_status()` for larger documents
- Check MCP server logs for processing errors

## Requirements

See `requirements.txt` for dependencies:
- `boto3>=1.26.0` - AWS SDK for Cognito authentication
- `requests>=2.31.0` - HTTP client for MCP gateway communication

## Security Best Practices

1. **Store credentials securely:**
   ```bash
   # Use environment variables
   export MCP_USERNAME="your-username"
   export MCP_PASSWORD="your-password"
   ```

2. **Use AWS Secrets Manager:**
   ```python
   import boto3
   secrets = boto3.client('secretsmanager')
   secret = secrets.get_secret_value(SecretId='mcp-credentials')
   ```

3. **Rotate credentials regularly**
4. **Use temporary credentials when possible**
5. **Never commit credentials to version control**
6. **Use `.gitignore` to exclude config files:**
   ```
   mcp_client_config.properties
   ```

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review MCP server logs
3. Verify configuration properties
4. Check network connectivity to the gateway
