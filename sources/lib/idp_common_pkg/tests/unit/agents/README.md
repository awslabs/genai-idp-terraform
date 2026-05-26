# Agents Unit Tests

This directory contains comprehensive unit tests for the IDP Common agents module. The tests are organized by functionality and follow pytest conventions with proper mocking and isolation.

## Test Structure

```
tests/unit/agents/
├── README.md                    # This file
├── __init__.py                  # Test module initialization
├── test_common_config.py        # Tests for common configuration utilities
├── analytics/                   # Analytics agent specific tests
│   ├── __init__.py
│   ├── test_agent.py           # Analytics agent creation tests
│   ├── test_config.py          # Analytics configuration tests
│   ├── test_integration.py     # Integration tests for analytics components
│   └── test_tools.py           # Individual tool tests
├── error_analyzer/              # Error analyzer agent specific tests
│   ├── __init__.py
│   ├── test_agent.py           # Error analyzer agent creation tests
│   ├── test_config.py          # Error analyzer configuration tests
│   └── test_tools.py           # Individual tool tests
├── orchestrator/                # Orchestrator agent specific tests
│   ├── __init__.py
│   └── test_conversational_orchestrator.py  # Conversational orchestrator tests
└── common/                      # Common agent utilities tests
    └── test_monitoring.py      # Monitoring and message tracking tests
```

## Running Tests

### Run All Agent Tests
```bash
# From the idp_common_pkg directory
pytest tests/unit/agents/ -v
```

### Run Specific Test Categories
```bash
# Common configuration tests
pytest tests/unit/agents/test_common_config.py -v

# Analytics agent tests
pytest tests/unit/agents/analytics/ -v

# Error analyzer agent tests
pytest tests/unit/agents/error_analyzer/ -v

# Orchestrator agent tests
pytest tests/unit/agents/orchestrator/ -v

# Specific test file
pytest tests/unit/agents/analytics/test_tools.py -v
```

### Run with Coverage
```bash
pytest tests/unit/agents/ --cov=idp_common.agents --cov-report=html
```

## Test Files Overview

### `test_common_config.py`

Tests the shared configuration utilities used by all agent types.

**Test Classes:**
- `TestGetEnvironmentConfig`: Tests environment variable loading and validation
- `TestValidateAwsCredentials`: Tests AWS credential validation

**Key Test Cases:**
- `test_get_basic_config()`: Verifies basic configuration loading without required keys
- `test_get_config_with_default_region()`: Tests default AWS region fallback (us-east-1)
- `test_get_config_with_required_keys()`: Tests configuration with required environment variables
- `test_missing_required_keys_raises_error()`: Ensures missing required keys raise ValueError
- `test_partial_missing_required_keys()`: Tests partial missing keys scenario
- `test_explicit_credentials_available()`: Tests explicit AWS credential validation
- `test_lambda_environment()`: Tests credential validation in Lambda environment
- `test_default_credential_chain()`: Tests default AWS credential chain validation

### `analytics/test_config.py`

Tests analytics-specific configuration loading and validation.

**Test Classes:**
- `TestGetAnalyticsConfig`: Tests analytics configuration loading
- `TestLoadDbDescription`: Tests database description file loading
- `TestLoadResultFormatDescription`: Tests result format description loading

**Key Test Cases:**
- `test_get_analytics_config_success()`: Tests successful analytics config loading with all required variables
- `test_missing_required_config_raises_error()`: Tests error handling for missing required config
- `test_all_missing_required_config()`: Tests scenario with all required config missing
- `test_load_db_description_success()`: Tests successful database description file loading
- `test_load_db_description_file_not_found()`: Tests graceful handling of missing db description file
- `test_load_result_format_description_success()`: Tests successful result format description loading
- `test_load_result_format_description_file_not_found()`: Tests handling of missing result format file

### `analytics/test_agent.py`

Tests the analytics agent creation and configuration.

**Test Classes:**
- `TestCreateAnalyticsAgent`: Tests analytics agent factory function

**Key Test Cases:**
- `test_create_analytics_agent_success()`: Tests successful agent creation with proper configuration
- `test_create_analytics_agent_tools_configured()`: Verifies that all required tools are properly configured
- `test_create_analytics_agent_handles_asset_loading_error()`: Tests graceful handling of asset loading errors

**Mocked Components:**
- Strands Agent class
- Database description loading
- Result format description loading
- Boto3 session creation

### `analytics/test_tools.py`

Tests individual analytics tools functionality.

**Test Classes:**
- `TestRunAthenaQuery`: Tests Athena query execution tool
- `TestExecutePython`: Tests Python code execution tool

**Key Test Cases:**

#### Athena Query Tool Tests:
- `test_successful_query_execution()`: Tests successful Athena query with proper result formatting
- `test_failed_query_execution()`: Tests handling of failed Athena queries
- `test_query_execution_exception()`: Tests exception handling during query execution

#### Python Execution Tool Tests:
- `test_successful_python_execution()`: Tests successful Python code execution
- `test_python_execution_with_error()`: Tests error handling in Python code execution
- `test_python_execution_with_pandas()`: Tests pandas availability and usage
- `test_python_execution_output_capture()`: Tests proper stdout/stderr capture

**Mocked Components:**
- Boto3 Athena client
- Query execution responses
- Query results
- Python execution environment

### `analytics/test_integration.py`

Integration tests that verify components work together correctly.

**Test Classes:**
- `TestAnalyticsIntegration`: End-to-end integration tests

**Key Test Cases:**
- `test_end_to_end_agent_creation()`: Tests complete agent creation flow from config to agent
- `test_configuration_validation()`: Tests that configuration validation works across components
- `test_missing_configuration_raises_error()`: Tests error propagation through the integration stack

**Integration Points Tested:**
- Configuration loading → Agent creation
- Environment variables → Configuration validation
- Asset loading → Agent initialization
- Tool configuration → Agent setup

### `orchestrator/test_conversational_orchestrator.py`

Tests the conversational orchestrator creation and configuration.

**Test Classes:**
- `TestConversationalOrchestrator`: Tests conversational orchestrator factory method

**Key Test Cases:**
- `test_create_conversational_orchestrator_basic()`: Tests successful orchestrator creation with memory and conversation management
- `test_memory_provider_configuration()`: Verifies DynamoDB memory provider is configured with correct parameters
- `test_conversation_manager_configuration()`: Tests conversation manager setup and configuration
- `test_invalid_agent_id()`: Tests error handling for non-existent agents
- `test_missing_memory_table_env_var()`: Tests graceful degradation when memory table is not configured
- `test_multiple_agents()`: Tests orchestrator creation with multiple specialized agents
- `test_returns_raw_strands_agent()`: Verifies raw Strands agent is returned (not wrapped in IDPAgent)

**Mocked Components:**
- Strands orchestrator agent creation
- DynamoDB memory provider
- Conversation manager
- Environment variables

## Test Patterns and Best Practices

### Mocking Strategy

**Environment Variables:**
```python
@patch.dict(os.environ, {"VAR_NAME": "value"}, clear=True)
def test_function(self):
    # Test with controlled environment
```

**File Operations:**
```python
@patch("builtins.open", new_callable=mock_open, read_data="content")
def test_file_loading(self, mock_file):
    # Test file loading without actual files
```

**AWS Services:**
```python
mock_client = MagicMock()
mock_client.method.return_value = {"expected": "response"}
with patch("boto3.client", return_value=mock_client):
    # Test AWS service interactions
```

### Test Isolation

- Each test uses `clear=True` in `patch.dict` to ensure clean environment
- Mocks are properly configured and reset between tests
- No external dependencies (files, AWS services, network) in unit tests
- Proper exception testing with `pytest.raises`

### Assertion Patterns

**Configuration Tests:**
```python
assert config["key"] == "expected_value"
assert "required_key" in config
```

**Error Testing:**
```python
with pytest.raises(ValueError) as exc_info:
    function_call()
assert "expected_message" in str(exc_info.value)
```

**Mock Verification:**
```python
mock_function.assert_called_once_with(expected_args)
assert mock_function.call_count == expected_count
```

## Coverage Expectations

### Target Coverage Areas

1. **Configuration Loading**: All environment variable scenarios
2. **Error Handling**: All exception paths and error conditions
3. **Tool Functionality**: All tool methods and their edge cases
4. **Agent Creation**: All factory function paths
5. **Integration Points**: Component interaction scenarios

### Current Coverage Focus

- ✅ Environment variable validation
- ✅ Configuration loading and defaults
- ✅ File loading with error handling
- ✅ AWS service mocking
- ✅ Tool execution scenarios
- ✅ Agent creation workflows
- ✅ Error propagation testing

## Adding New Tests

### For New Agent Types

1. **Create agent-specific test directory**:
   ```
   tests/unit/agents/new_agent_type/
   ├── __init__.py
   ├── test_agent.py
   ├── test_config.py
   ├── test_tools.py
   └── test_integration.py
   ```

2. **Follow existing patterns**:
   - Use `@pytest.mark.unit` decorator
   - Mock external dependencies
   - Test both success and failure scenarios
   - Include integration tests

3. **Update this README** with new test descriptions

### For New Tools

1. **Add to appropriate `test_tools.py`**
2. **Test patterns to include**:
   - Successful execution
   - Error handling
   - Input validation
   - Output formatting
   - External service mocking

### Test Naming Conventions

- Test files: `test_<module_name>.py`
- Test classes: `Test<ClassName>`
- Test methods: `test_<specific_scenario>()`
- Use descriptive names that explain the scenario being tested

## Debugging Test Failures

### Common Issues

**Import Errors:**
```bash
# Ensure you're in the right directory
cd lib/idp_common_pkg
# Install in development mode
pip install -e .
```

**Mock Configuration:**
```python
# Ensure mocks are properly configured before use
mock_object.configure_mock(attribute=value)
```

**Environment Isolation:**
```python
# Use clear=True to avoid environment pollution
@patch.dict(os.environ, {...}, clear=True)
```

### Verbose Test Output

```bash
# Run with verbose output and no capture
pytest tests/unit/agents/ -v -s

# Show local variables on failure
pytest tests/unit/agents/ -l

# Drop into debugger on failure
pytest tests/unit/agents/ --pdb
```

## Continuous Integration

These tests are designed to run in CI/CD environments:

- No external dependencies
- Deterministic results
- Fast execution
- Comprehensive error reporting
- Proper exit codes

The tests validate that the agents module works correctly before deployment and ensure that changes don't break existing functionality.
