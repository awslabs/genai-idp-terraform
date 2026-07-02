# IDP MCP Connector

Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
SPDX-License-Identifier: MIT-0

A lightweight local MCP server that bridges IDE AI assistants (Cline, Kiro) to the IDP Accelerator's remote MCP Server on Amazon Bedrock AgentCore Gateway.

## Why This Exists

The IDP Accelerator exposes document processing capabilities through a remote MCP Server protected by Cognito OAuth. IDE tools like Cline use OAuth 2.1 Dynamic Client Registration (RFC 7591) which Cognito does not support — resulting in `HTTP 403 Dynamic client registration failed` when connecting directly.

The connector runs locally on your machine, authenticates with your pre-registered Cognito credentials, dynamically discovers all available tools from the remote server, and presents them to your IDE as a standard stdio MCP server.

```
Cline/Kiro ←─stdio (MCP)─→ idp_mcp_connector ←─HTTPS + OAuth─→ AgentCore Gateway → IDP Lambda
```

## Prerequisites

- Python 3.11+
- IDP Accelerator stack deployed with `EnableMCP: 'true'`
- The following values from your CloudFormation stack outputs:
  - `MCPServerEndpoint`
  - `MCPTokenURL`
  - `MCPClientId`
  - `MCPClientSecret`

## Installation

```bash
# From the genaiic-idp-accelerator root directory
pip install -e lib/idp_mcp_connector_pkg

# Or with uv
uv pip install -e lib/idp_mcp_connector_pkg
```

## Quick Start: Cline (VS Code and JetBrains)

Regardless of which IDE you use (VS Code or JetBrains/PyCharm), Cline stores MCP server configuration in a single shared file:

```
~/.cline/data/settings/cline_mcp_settings.json
```

On macOS this expands to `/Users/<your-username>/.cline/data/settings/cline_mcp_settings.json`.

**Steps:**

1. Open that file in any text editor (or from within the Cline UI — see below)
2. Add the `idp-accelerator` server entry:

```json
{
  "mcpServers": {
    "idp-accelerator": {
      "command": "python3",
      "args": ["-m", "idp_mcp_connector"],
      "env": {
        "IDP_MCP_ENDPOINT": "<MCPServerEndpoint>",
        "IDP_MCP_TOKEN_URL": "<MCPTokenURL>",
        "IDP_MCP_CLIENT_ID": "<MCPClientId>",
        "IDP_MCP_CLIENT_SECRET": "<MCPClientSecret>"
      }
    }
  }
}
```

> **Windows**: Use `"command": "python"` instead of `"python3"`.

3. Save the file.

**To open the file from the Cline UI:**

- **VS Code**: Cline sidebar → MCP Servers icon → Configure tab → "Configure MCP Servers"
- **JetBrains (PyCharm)**: Cline tool window → MCP Servers → Settings gear icon → "Edit MCP Settings"

Both options open the same `~/.cline/data/settings/cline_mcp_settings.json` file. After saving, Cline automatically detects the change and launches the connector process.

**Verify the connection:**
- Click the **MCP Servers icon** in the Cline panel (top right)
- Select the **"Installed"** tab (or **"Configure"** tab)
- Look for **`idp-accelerator`** with a **🟢 green dot** — this means the connector is running and authenticated
- Click on **`idp-accelerator`** to expand it — you should see all 5 tools listed:
  - `search`
  - `process`
  - `reprocess`
  - `status`
  - `get_results`
- A **🔴 red dot** means the connector failed to start — check the troubleshooting section below

See `settings/cline_mcp_settings.json` and `settings/kiro_mcp_settings.json` for ready-to-edit configuration templates.

> **Note**: The package directory is named `idp_mcp_connector_pkg` (consistent with `idp_cli_pkg`, `idp_common_pkg`) but the importable Python module is `idp_mcp_connector`. Users always reference the module name (`python -m idp_mcp_connector`), not the directory name.

## Configuration

All configuration is via environment variables:

| Variable | Required | CloudFormation Output | Description |
|----------|----------|----------------------|-------------|
| `IDP_MCP_ENDPOINT` | ✅ | `MCPServerEndpoint` | AgentCore Gateway URL |
| `IDP_MCP_TOKEN_URL` | ✅ | `MCPTokenURL` | Cognito token endpoint |
| `IDP_MCP_CLIENT_ID` | ✅ | `MCPClientId` | Cognito client ID |
| `IDP_MCP_CLIENT_SECRET` | ✅ | `MCPClientSecret` | Cognito client secret |

## Available Tools

The connector dynamically discovers tools from the IDP MCP Server at startup. Current tools:

| Tool | Description |
|------|-------------|
| `search` | Natural language queries on document analytics |
| `process` | Submit documents for processing (S3 URI or base64) |
| `reprocess` | Re-run classification or extraction on documents |
| `status` | Check batch processing status |
| `get_results` | Retrieve extracted fields and confidence scores |

## Testing the Connection

```bash
export IDP_MCP_ENDPOINT="https://..."
export IDP_MCP_TOKEN_URL="https://..."
export IDP_MCP_CLIENT_ID="..."
export IDP_MCP_CLIENT_SECRET="..."

python -m idp_mcp_connector
# Expected output:
# IDP MCP Connector starting...
# Authenticating with Cognito...
# Authentication successful. Token valid for 3600s.
# Discovering tools from IDP MCP Server...
# Discovered 5 tools: search, process, reprocess, status, get_results
# IDP MCP Connector ready. Listening on stdio.
```

## Package Structure

```
idp_mcp_connector/
├── __init__.py       # Package exports and version
├── __main__.py       # Entry point: reads env vars, starts connector
├── auth.py           # Cognito OAuth token management (client_credentials)
└── connector.py      # Core: tool discovery + transparent forwarding to AgentCore Gateway
```

## Full Documentation

See [`docs/mcp-connector.md`](../../docs/mcp-connector.md) for complete architecture, design details, demo scenarios, and troubleshooting guide.
