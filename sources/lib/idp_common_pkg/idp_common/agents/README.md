# IDP Common Agents Module

This module provides agent-based functionality using the Strands framework for the GenAI IDP Accelerator. All agents are built on top of Strands agents and tools, providing intelligent document processing capabilities.

## Overview

The agents module is designed to support multiple types of intelligent agents while maintaining consistency and reusability across the IDP accelerator. Currently implemented:

- **Analytics Agent**: Natural language to SQL/visualization conversion with secure code execution
- **External MCP Agent**: Connects to external MCP servers to provide additional tools and capabilities
- **Dummy Agent**: Simple development agent with calculator tool for testing
- **Common Utilities**: Shared configuration, monitoring, and utilities for all agent types

## Architecture

```
idp_common/agents/
├── README.md                    # This file
├── __init__.py                  # Module initialization with lazy loading
├── common/                      # Shared utilities for all agent types
│   ├── __init__.py
│   ├── config.py               # Common configuration patterns
│   ├── monitoring.py           # Agent execution monitoring and hooks
│   ├── dynamodb_logger.py      # DynamoDB integration for message persistence
│   └── response_utils.py       # Response parsing utilities
├── analytics/                   # Analytics agent implementation
│   ├── __init__.py
│   ├── agent.py                # Analytics agent factory
│   ├── config.py               # Analytics-specific configuration
│   ├── utils.py                # Cleanup and utility functions
│   ├── tools/                  # Strands tools for analytics
│   │   ├── __init__.py
│   │   ├── athena_tool.py      # Athena query execution
│   │   ├── get_database_info_tool.py # Database schema information
│   │   └── code_interpreter_tools.py # Secure Python code execution
│   └── assets/                 # Static assets (prompts, schemas)
│       └── db_description.md   # Database schema documentation
├── external_mcp/               # External MCP agent implementation
│   ├── __init__.py
│   ├── agent.py                # External MCP agent factory
│   └── config.py               # MCP-specific configuration
├── sample_calculator/          # Sample calculator agent for development/testing
│   ├── __init__.py
│   └── agent.py                # Simple calculator agent
├── factory/                    # Agent factory and registry
│   ├── __init__.py
│   ├── agent_factory.py        # Core factory implementation
│   └── registry.py             # Global agent registration
└── testing/                    # Testing utilities and examples
    ├── __init__.py
    ├── README.md               # Comprehensive testing guide
    ├── test_analytics.py
    ├── run_analytics_test.py
    ├── .env.example
    └── .env                    # Local environment configuration (gitignored)
```

## Design Principles

### 1. Strands-First Approach
All agents use the Strands framework directly without unnecessary abstraction layers. This provides:
- Excellent tool abstractions via `@tool` decorator
- Built-in agent management and conversation handling
- Consistent patterns across all agent types

### 2. Simple Factory Pattern
Each agent type follows a simple pattern:
- `agent.py` - Factory function to create configured Strands agents
- `config.py` - Simple configuration management
- `tools/` - Strands tools specific to that agent type
- `assets/` - Static assets like prompts, schemas, etc.

### 3. Security-First Design
Agents are designed with security as a primary concern:
- **Sandboxed Code Execution**: Uses AWS Bedrock AgentCore for secure Python execution
- **Data Isolation**: Query results are transferred securely between services
- **Minimal Permissions**: Each agent requests only necessary AWS permissions
- **Audit Trail**: Comprehensive logging and monitoring for security reviews

### 4. IDP Integration
Agents are designed to integrate seamlessly with the IDP accelerator:
- Environment variable configuration for Lambda deployment
- AWS service integration (Athena, S3, AgentCore, etc.)
- Consistent logging patterns
- Error handling that works in serverless environments

## Security Architecture

### AgentCore Integration

The analytics agent uses **AWS Bedrock AgentCore** for secure Python code execution. This is a critical security decision that ensures:

- **Sandboxed Environment**: Python code runs in an isolated, secure sandbox
- **No Direct File System Access**: Code cannot access the Lambda file system
- **Controlled Data Transfer**: Query results are securely transferred via S3 and AgentCore APIs
- **Session Management**: Code interpreter sessions are properly managed and cleaned up

### Data Flow Security

1. **Query Execution**: SQL queries run against Athena with results stored in S3
2. **Secure Transfer**: Agent downloads CSV results from S3 using boto3
3. **Sandbox Injection**: CSV data is written to the AgentCore sandbox using the `writeFiles` API
4. **Code Execution**: Python visualization code runs in the isolated sandbox
5. **Result Extraction**: Generated plots/tables are returned as JSON through AgentCore APIs

This architecture ensures that arbitrary Python code (used for generating plots and tables) never executes in the Lambda environment, providing a secure foundation for future application security reviews.

## Usage

### Analytics Agent

The analytics agent provides natural language to SQL/visualization conversion with four main tools:

1. **Athena Query Tool** (`athena_tool.py`): Executes SQL queries against AWS Athena
2. **Database Info Tool** (`get_database_info_tool.py`): Provides database schema information
3. **Code Sandbox Writer** (`code_interpreter_tools.py`): Securely transfers query results to sandbox
4. **Python Executor** (`code_interpreter_tools.py`): Executes visualization code in secure sandbox

```python
from idp_common.agents.analytics import create_analytics_agent, get_analytics_config

# Get configuration from environment variables
config = get_analytics_config()

# Create the agent with monitoring context
agent = create_analytics_agent(
    config, 
    session=boto3.Session(), 
    job_id="analytics-job-123", 
    user_id="user-456"
)

# Use the agent
response = agent("How many documents were processed last week?")
```

### External MCP Agent

The External MCP Agent connects to external MCP (Model Context Protocol) servers to provide additional tools and capabilities. This agent enables integration with third-party services and custom tools hosted outside the IDP system.

**Key Features:**
- **Cross-Account Support**: MCP servers can be hosted in separate AWS accounts
- **OAuth Authentication**: Uses AWS Cognito for secure authentication
- **Dynamic Tool Discovery**: Automatically discovers and integrates available MCP tools
- **Context Management**: Maintains MCP client connections throughout agent lifecycle

**Configuration:**
The agent requires credentials stored in AWS Secrets Manager at `{StackName}/external-mcp-agents/credentials` as a JSON array:

```json
[
  {
    "mcp_url": "https://your-first-mcp-server.com/mcp",
    "cognito_user_pool_id": "us-east-1_XXXXXXXXX",
    "cognito_client_id": "xxxxxxxxxxxxxxxxxxxxxxxxxx", 
    "cognito_username": "<your first user here>",
    "cognito_password": "<your first password here>",
    "agent_name": "My Custom Calculator Agent",
    "agent_description": "Provides advanced mathematical calculations"
  },
  {
    "mcp_url": "https://your-second-mcp-server.com/mcp",
    "cognito_user_pool_id": "us-east-1_YYYYYYYYY",
    "cognito_client_id": "yyyyyyyyyyyyyyyyyyyyyyyyyy", 
    "cognito_username": "<your second user here>",
    "cognito_password": "<your second password here>"
  }
]
```

**Optional Fields:**
- `agent_name`: Custom name for the agent (defaults to "External MCP Agent {N}")
- `agent_description`: Custom description (tool information is automatically appended)

**Usage:**
```python
from idp_common.agents.factory import agent_factory

# Multiple MCP agents are automatically registered (external-mcp-agent-1, external-mcp-agent-2, etc.)
with agent_factory.create_agent(
    agent_id="external-mcp-agent-1",
    session=session
) as agent:
    response = agent("Use your external tools to help me")
```

**Security:**
- Uses streamable HTTP transport with OAuth bearer tokens
- Credentials managed through AWS Secrets Manager
- MCP client context properly managed to prevent connection leaks

For detailed setup instructions, see [Custom MCP Agent Documentation](../../docs/custom-MCP-agent.md).

For guidance on deploying your own MCP servers with Cognito authentication, see the [AWS Bedrock Agent Core MCP Documentation](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/runtime-mcp.html).

### Response Parsing

The analytics agent returns structured responses that can be parsed:

```python
from idp_common.agents.analytics import parse_agent_response

# Parse the agent response
result = parse_agent_response(response)

# Result contains:
# - responseType: "text", "table", or "plotData"
# - content: Text content (for text responses)
# - tableData: Structured table data (for table responses)
# - plotData: Chart.js compatible plot data (for plot responses)
```

### Common Configuration

```python
from idp_common.agents.common import get_environment_config

# Get basic configuration with validation
config = get_environment_config(["REQUIRED_VAR1", "REQUIRED_VAR2"])
```

## Monitoring and Observability

The agents module includes comprehensive monitoring capabilities:

### Agent Monitoring

```python
from idp_common.agents.common.monitoring import AgentMonitor

# Create agent with monitoring
agent_monitor = AgentMonitor(
    log_level=logging.INFO, 
    enable_detailed_logging=True
)
agent.hooks.add_hook(agent_monitor)

# Get execution report
report = agent_monitor.get_execution_report()
```

### DynamoDB Message Persistence

```python
from idp_common.agents.common.dynamodb_logger import DynamoDBMessageTracker

# Add message persistence
message_tracker = DynamoDBMessageTracker(
    job_id="analytics-job-123", 
    user_id="user-456"
)
agent.hooks.add_hook(message_tracker)
```

## Adding New Agent Types

To add a new agent type (e.g., `document_analysis`):

1. **Create the directory structure**:
   ```
   idp_common/agents/document_analysis/
   ├── __init__.py
   ├── agent.py
   ├── config.py
   ├── tools/
   │   └── __init__.py
   └── assets/
   ```

2. **Implement the factory function** (`agent.py`):
   ```python
   from strands import Agent
   from .tools import your_tool1, your_tool2, your_tool3
   
   def create_document_analysis_agent(config, session, **kwargs):
       tools = [your_tool1, your_tool2, your_tool3]
       system_prompt = "Your agent prompt here..."
       return Agent(tools=tools, system_prompt=system_prompt)
   ```

3. **Add configuration management** (`config.py`):
   ```python
   from ..common.config import get_environment_config
   
   def get_document_analysis_config():
       return get_environment_config(["REQUIRED_ENV_VAR"])
   ```

4. **Create Strands tools** (`tools/`):
   ```python
   from strands import tool
   
   @tool
   def your_tool(input_param: str) -> dict:
       # Tool implementation
       return {"result": "processed"}
   ```

5. **Update the main module** (`__init__.py`):
   ```python
   # Add to the lazy loading list
   if name in ["analytics", "common", "document_analysis"]:
   ```

## Testing

The `testing/` directory provides utilities for testing agents locally:

- **Direct Testing**: Test agents outside of Lambda environment
- **Configuration Validation**: Verify environment setup
- **Response Analysis**: Parse and validate agent responses
- **AgentCore Integration**: Test code interpreter functionality

See [`testing/README.md`](./testing/README.md) for detailed testing instructions.

## Dependencies

### Core Dependencies
- `strands-agents>=1.0.0` - Core agent framework
- `boto3` - AWS service integration
- `bedrock-agentcore` - Secure code execution sandbox

### Analytics-Specific Dependencies
- `pandas>=2.0.0` - Data manipulation (used in sandbox)

### Required AWS Permissions

For analytics agents, the following IAM permissions are required:

```yaml
# Athena and Glue permissions
- athena:StartQueryExecution
- athena:GetQueryExecution
- athena:GetQueryResults
- glue:GetTable
- glue:GetTables
- glue:GetDatabase
- glue:GetDatabases

# S3 permissions for query results
- s3:GetObject
- s3:PutObject
- s3:DeleteObject

# Bedrock permissions
- bedrock:InvokeModel
- bedrock:InvokeModelWithResponseStream

# AgentCore permissions (CRITICAL for security)
- bedrock-agentcore:StartCodeInterpreterSession
- bedrock-agentcore:StopCodeInterpreterSession
- bedrock-agentcore:InvokeCodeInterpreter
- bedrock-agentcore:GetCodeInterpreterSession
- bedrock-agentcore:ListCodeInterpreterSessions
```

### Optional Dependencies
Install specific agent dependencies as needed:
```bash
# For analytics agents
pip install "idp_common[agents,analytics]"

# For all agent functionality
pip install "idp_common[all]"
```

## Integration with Lambda Functions

Agents are designed to work seamlessly in AWS Lambda:

```python
# In your Lambda function
from idp_common.agents.analytics import create_analytics_agent, get_analytics_config

def handler(event, context):
    # Change to /tmp for AgentCore compatibility
    os.chdir('/tmp')
    
    config = get_analytics_config()  # Loads from environment variables
    agent = create_analytics_agent(
        config, 
        session=boto3.Session(),
        job_id=event.get("jobId"),
        user_id=event.get("userId")
    )
    
    query = event.get("query")
    response = agent(query)
    
    return {"response": response}
```

### Lambda Environment Considerations

- **Working Directory**: Change to `/tmp` before creating agents (AgentCore requirement)
- **Session Management**: AgentCore sessions are automatically cleaned up
- **Memory Requirements**: Analytics agents require at least 1024MB memory
- **Timeout**: Set appropriate timeout (900s recommended for complex queries)

## Future Agent Types

The framework is designed to easily support additional agent types:

- **Document Analysis**: Understanding document structure and content
- **Workflow Automation**: Process automation and orchestration
- **Quality Assurance**: Validation and quality checking
- **Custom Agents**: Customer-specific implementations

Each would follow the same simple pattern established by the analytics agent, with appropriate security considerations for their specific use cases.

## Contributing

When adding new agents or modifying existing ones:

1. Follow the established directory structure
2. Use Strands tools with the `@tool` decorator
3. Implement comprehensive unit tests
4. Update this README with new agent types
5. Ensure Lambda compatibility
6. Follow existing logging and error handling patterns
7. **Security Review**: Ensure any code execution is properly sandboxed
8. **Permission Audit**: Document required AWS permissions

## Support

For questions about the agents module:
- Check the testing utilities in `testing/`
- Review existing agent implementations
- Consult the main IDP documentation
- Review security architecture for compliance requirements
