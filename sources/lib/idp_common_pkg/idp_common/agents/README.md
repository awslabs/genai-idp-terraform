# Conversational Agent System

A multi-turn conversational AI system that provides intelligent assistance through specialized agents with persistent memory and real-time streaming responses.

## Overview

The Conversational Agent System enables natural, multi-turn conversations with AI agents that can help with document analysis, data analytics, error diagnosis, and more. The system automatically routes user queries to the most appropriate specialized agent and maintains conversation history for contextual responses.

### Key Features

- **Multi-Turn Conversations**: Maintains context across multiple exchanges
- **Persistent Memory**: Stores conversation history in DynamoDB
- **Real-Time Streaming**: Streams responses as they're generated via AppSync
- **Automatic Agent Selection**: Orchestrator routes queries to the best agent
- **All Agents Available**: No manual agent selection needed
- **Session-Based**: Each conversation has a unique session ID

## Architecture

```
User Message
    ↓
AgentChatResolver (Lambda)
    ↓
Store in ChatMessagesTable (DynamoDB)
    ↓
Invoke AgentChatProcessor (Lambda)
    ↓
Create Conversational Orchestrator
    ├─ Load conversation history from memory
    ├─ Include all registered agents
    └─ Configure context management
    ↓
Stream Response via AppSync
    ├─ Publish chunks in real-time
    ├─ Store in memory table
    └─ Publish final response
    ↓
User receives streaming response
```

## Components

### 1. Lambda Functions

#### AgentChatResolver
- **Purpose**: Entry point for user messages
- **Location**: `src/lambda/agent_chat_resolver/`
- **Responsibilities**:
  - Validates incoming messages
  - Stores user messages in DynamoDB
  - Invokes the processor asynchronously
  - Returns immediate acknowledgment

#### AgentChatProcessor
- **Purpose**: Processes messages and generates responses
- **Location**: `src/lambda/agent_chat_processor/`
- **Responsibilities**:
  - Creates conversational orchestrator with all agents
  - Loads conversation history from memory
  - Streams responses in real-time
  - Stores responses in memory

### 2. Core Modules

#### Agent Factory (`factory/agent_factory.py`)
Central factory for creating and managing agents.

**Key Method**:
```python
create_conversational_orchestrator(
    agent_ids: List[str],
    session_id: str,
    config: Dict[str, Any],
    session: Any
) -> Agent
```

Creates an orchestrator with:
- Memory hooks for conversation history
- Conversation manager for context optimization
- All specified agents as tools

#### Memory Provider (`utils/memory_provider.py`)
Manages conversation history persistence in DynamoDB.

**Features**:
- Stores messages in JSON arrays within DynamoDB items
- Automatically loads recent conversation history
- Groups messages into turns for efficient context
- Handles message size limits with truncation
- Creates new items when approaching 400KB DynamoDB limit

**Usage**:
```python
from idp_common.agents.utils.memory_provider import DynamoDBMemoryHookProvider

memory_provider = DynamoDBMemoryHookProvider(
    table_name="IdpHelperChatMemoryTable",
    session_id="user-session-123",
    region_name="us-east-2",
    max_history_turns=20
)

# Add to agent
agent.hooks.add_hook(memory_provider)
```

#### Conversation Manager (`utils/conversation_manager.py`)
Optimizes conversation context to stay within token limits.

**Features**:
- Drops verbose tool results to reduce context size
- Applies sliding window to keep recent turns
- Preserves important context
- Configurable tool dropping and window size

**Usage**:
```python
from idp_common.agents.utils.conversation_manager import DropAndSlideConversationManager

conversation_manager = DropAndSlideConversationManager(
    tools_to_drop=("read_multiple_files",),
    keep_call_stub=True,
    window_size=20,
    should_truncate_results=True
)

# Add to agent
agent.conversation_manager = conversation_manager
```

### 3. Data Storage

#### ChatMessagesTable (DynamoDB)
Stores all chat messages for display and retrieval.

**Schema**:
- **PK**: `session_id` (e.g., "user-session-123")
- **SK**: `timestamp` (ISO-8601 format)
- **Attributes**: role, content, isProcessing, ExpiresAfter

#### IdHelperChatMemoryTable (DynamoDB)
Stores conversation history for agent memory.

**Schema**:
- **PK**: `conversation#{session_id}`
- **SK**: `timestamp` (ISO-8601 format)
- **Attributes**: conversation_history (JSON), message_count, last_updated

### 4. GraphQL API

#### Mutation: sendAgentChatMessage
Send a message to the conversational agent system.

```graphql
mutation SendMessage {
  sendAgentChatMessage(
    prompt: "How can I analyze document processing errors?"
    sessionId: "user-session-123"
    method: "chat"
  ) {
    role
    content
    timestamp
    isProcessing
    sessionId
  }
}
```

#### Subscription: onAgentChatMessageUpdate
Subscribe to real-time message updates.

```graphql
subscription WatchMessages {
  onAgentChatMessageUpdate(sessionId: "user-session-123") {
    role
    content
    timestamp
    isProcessing
  }
}
```

#### Query: getAgentChatMessages
Retrieve conversation history.

```graphql
query GetHistory {
  getAgentChatMessages(sessionId: "user-session-123") {
    role
    content
    timestamp
    sessionId
  }
}
```

## Available Agents

The system includes several specialized agents:

1. **Document Analysis Agent**: Analyzes document processing workflows
2. **Analytics Agent**: Queries and visualizes data from Athena
3. **Error Analyzer Agent**: Diagnoses errors in CloudWatch logs
4. **Sample Calculator Agent**: Performs calculations and data analysis
5. **External MCP Agents**: Connects to external MCP servers

All agents are automatically available to the orchestrator - no manual selection needed.

## Usage Examples

### Basic Conversation

```python
# Send a message
response = lambda_client.invoke(
    FunctionName='AgentChatResolverFunction',
    Payload=json.dumps({
        "arguments": {
            "prompt": "What agents are available?",
            "sessionId": "user-session-123",
            "method": "chat"
        }
    })
)

# The processor will:
# 1. Load conversation history
# 2. Create orchestrator with all agents
# 3. Stream response in real-time
# 4. Store in memory for next turn
```

### Multi-Turn Conversation

```python
# First message
send_message("Tell me about document processing", "session-456")

# Second message (has context from first)
send_message("How do I fix errors?", "session-456")

# The agent remembers the context about document processing
```

### Testing

Run the backend test script:

```bash
python tests/test_agent_chat_backend.py --stack-name IDP --region us-east-2
```

This tests:
- Message storage in DynamoDB
- Processor invocation
- Assistant response generation
- Memory persistence
- Multi-turn conversations

## Configuration

### Environment Variables

#### AgentChatResolver
- `CHAT_MESSAGES_TABLE`: DynamoDB table for messages
- `AGENT_CHAT_PROCESSOR_FUNCTION`: Processor function name
- `DATA_RETENTION_DAYS`: TTL for messages (default: 30)

#### AgentChatProcessor
- `CHAT_MESSAGES_TABLE`: DynamoDB table for messages
- `ID_HELPER_CHAT_MEMORY_TABLE`: DynamoDB table for memory
- `BEDROCK_REGION`: AWS region for Bedrock/DynamoDB
- `MEMORY_METHOD`: Memory storage method (default: "dynamodb")
- `STREAMING_ENABLED`: Enable streaming (default: true)
- `MAX_CONVERSATION_TURNS`: Max turns to load (default: 20)
- `MAX_MESSAGE_SIZE_KB`: Max message size (default: 8.5)
- `APPSYNC_API_URL`: AppSync endpoint for streaming

### CloudFormation Resources

The system is deployed via CloudFormation with these key resources:

- `AgentChatResolverFunction`: Resolver Lambda
- `AgentChatProcessorFunction`: Processor Lambda
- `ChatMessagesTable`: Message storage
- `IdHelperChatMemoryTable`: Memory storage
- `SendAgentChatMessageResolver`: AppSync resolver
- `OnAgentChatMessageUpdate`: AppSync subscription

## How It Works

### 1. User Sends Message

User sends a message via GraphQL mutation:
```graphql
sendAgentChatMessage(prompt: "Hello", sessionId: "session-123")
```

### 2. Resolver Stores Message

`AgentChatResolver` Lambda:
- Validates the message
- Stores in `ChatMessagesTable` with PK=sessionId, SK=timestamp
- Invokes `AgentChatProcessor` asynchronously
- Returns immediate acknowledgment

### 3. Processor Creates Orchestrator

`AgentChatProcessor` Lambda:
- Gets ALL registered agents automatically
- Creates conversational orchestrator with:
  - Memory provider (loads last 20 turns)
  - Conversation manager (optimizes context)
  - All agents as tools

### 4. Orchestrator Processes Message

The orchestrator:
- Analyzes the user's query
- Selects the most appropriate agent
- Routes the query to that agent
- Generates a response

### 5. Response Streams Back

As the response is generated:
- Chunks are published via AppSync mutation
- Frontend receives real-time updates via subscription
- Thinking tags are removed for clean display
- Final response is stored in memory

### 6. Memory Persists

After the response:
- Full conversation stored in `IdHelperChatMemoryTable`
- Available for next turn in the conversation
- Grouped into turns for efficient loading

## Development

### Adding a New Agent

1. Create agent implementation in `agents/{agent_name}/`
2. Register with factory in `agents/__init__.py`:

```python
from .factory import agent_factory
from .my_agent import create_my_agent

agent_factory.register_agent(
    agent_id="my-agent",
    agent_name="My Agent",
    agent_description="Does something useful",
    creator_func=create_my_agent,
    sample_queries=["example query"]
)
```

3. Agent is automatically available to orchestrator!

### Testing Your Agent

```python
# Unit test
from idp_common.agents.factory import agent_factory

agent = agent_factory.create_agent(
    agent_id="my-agent",
    config=config,
    session=session
)

response = agent("test query")
```

### Running Unit Tests

```bash
# Test conversational orchestrator
cd lib/idp_common_pkg/idp_common/agents/testing
python run_conversational_orchestrator_test.py

# Or with pytest
pytest test_conversational_orchestrator.py -v
```

## Troubleshooting

### No Assistant Response

**Check CloudWatch Logs**:
```bash
aws logs tail /aws/lambda/{ProcessorFunctionName} --follow --region us-east-2
```

Look for:
- Import errors
- Bedrock permission issues
- Memory table access errors
- Orchestrator creation failures

### Memory Not Persisting

**Verify table access**:
- Check IAM permissions for `IdHelperChatMemoryTable`
- Verify `BEDROCK_REGION` environment variable
- Check CloudWatch logs for DynamoDB errors

### Streaming Not Working

**Check AppSync**:
- Verify `APPSYNC_API_URL` is set correctly
- Check IAM permissions for `appsync:GraphQL`
- Verify subscription is active in frontend

### Context Not Maintained

**Check memory loading**:
- Verify `MAX_CONVERSATION_TURNS` is set
- Check memory table has conversation history
- Look for "Loaded X conversation turns" in logs

## Performance

- **Cold Start**: ~5-10 seconds (first invocation)
- **Warm Start**: ~1-2 seconds (subsequent invocations)
- **Response Time**: 30-60 seconds (depends on agent complexity)
- **Memory Size**: 128 MB (resolver), 3072 MB (processor)
- **Timeout**: 30 seconds (resolver), 600 seconds (processor)

## Security

- **Authentication**: Cognito User Pools or IAM
- **Authorization**: AppSync resolvers enforce auth
- **Encryption**: KMS encryption for DynamoDB tables
- **TTL**: Messages expire after 30 days (configurable)
- **VPC**: Not required (uses AWS service APIs)

## Monitoring

### Key Metrics

- Lambda invocations (resolver and processor)
- Lambda duration and errors
- DynamoDB read/write capacity
- AppSync request count
- Bedrock API calls

### CloudWatch Logs

- `/aws/lambda/{ResolverFunctionName}`: Resolver logs
- `/aws/lambda/{ProcessorFunctionName}`: Processor logs

### Alarms

Consider setting up alarms for:
- Lambda errors > 5%
- Lambda duration > 500 seconds
- DynamoDB throttling
- Bedrock API errors

## Cost Optimization

- **DynamoDB**: On-demand pricing, TTL reduces storage
- **Lambda**: Pay per invocation, warm starts reduce cost
- **Bedrock**: Pay per token, context management reduces usage
- **AppSync**: Pay per request and data transfer

## Future Enhancements

- [ ] Support for file attachments
- [ ] Agent-specific memory (per-agent context)
- [ ] Conversation branching
- [ ] Export conversation history
- [ ] Custom agent selection
- [ ] Rate limiting per user
- [ ] Cost tracking per conversation

## Support

For issues or questions:
1. Check CloudWatch logs
2. Review this documentation
3. Run backend test script
4. Check DynamoDB tables for data
5. Verify environment variables

## License

Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0
