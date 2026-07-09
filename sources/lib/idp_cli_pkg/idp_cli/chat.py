# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Chat command for idp-cli.

Runs the Agent Companion Chat orchestrator locally, providing interactive
access to Analytics, Error Analyzer, and other agents from the terminal.
"""

import asyncio
import logging
import re
import uuid
from typing import Optional

from rich.console import Console

logger = logging.getLogger(__name__)
console = Console()


def run_chat(
    stack_name: str,
    region: Optional[str] = None,
    prompt: Optional[str] = None,
    enable_code_intelligence: bool = False,
):
    """
    Run the chat command — interactive REPL or single-shot.

    Args:
        stack_name: CloudFormation stack name
        region: AWS region
        prompt: If provided, run single-shot and exit
    """
    console.print("[bold blue]IDP Agent Chat[/bold blue]")
    console.print(f"[dim]Stack: {stack_name}[/dim]")
    console.print()

    # Use IDPClient to access chat processor internals
    from idp_sdk import IDPClient

    # Suppress all logging — agents are very chatty
    logging.disable(logging.CRITICAL)

    try:
        client = IDPClient(stack_name=stack_name, region=region)
        processor = client.chat._get_processor()

        with console.status("[bold]Discovering stack resources..."):
            processor._setup_env()

        session_id = f"cli-{uuid.uuid4().hex[:12]}"

        with console.status("[bold]Initializing agents..."):
            processor._ensure_orchestrator(
                session_id,
                enable_code_intelligence=enable_code_intelligence,
            )

        # Show available agents
        from idp_common.agents.factory import agent_factory

        agents = agent_factory.list_available_agents()
        agent_names = [a["agent_name"] for a in agents]
        console.print(
            f"[green]✓ Ready[/green]  [dim]Agents: {' · '.join(agent_names)}[/dim]"
        )
        console.print("[dim]Type /quit to exit[/dim]\n")

        if prompt:
            _handle_prompt(processor._orchestrator, prompt)
            return

        # Interactive REPL — reuse a single event loop for the session
        loop = asyncio.new_event_loop()
        try:
            while True:
                try:
                    user_input = console.input("[bold cyan]You:[/bold cyan] ")
                except (EOFError, KeyboardInterrupt):
                    console.print("\n[dim]Goodbye.[/dim]")
                    break

                text = user_input.strip()
                if not text:
                    continue
                if text.lower() in ("/quit", "/exit", "quit", "exit"):
                    console.print("[dim]Goodbye.[/dim]")
                    break

                _handle_prompt(processor._orchestrator, text, loop=loop)
        finally:
            loop.close()
    finally:
        # Restore logging so callers aren't permanently silenced
        logging.disable(logging.NOTSET)


def _handle_prompt(orchestrator, prompt: str, loop=None):
    """Send a prompt to the orchestrator and stream the response."""
    console.print()

    if loop is not None:
        # Reuse persistent loop (interactive REPL)
        try:
            loop.run_until_complete(_stream_response(orchestrator, prompt))
        except Exception as e:
            console.print(f"[red]Error: {e}[/red]")
    else:
        # One-shot mode — create and tear down a loop
        one_shot = asyncio.new_event_loop()
        try:
            one_shot.run_until_complete(_stream_response(orchestrator, prompt))
        except Exception as e:
            console.print(f"[red]Error: {e}[/red]")
        finally:
            one_shot.close()

    console.print()


async def _stream_response(orchestrator, prompt: str) -> str:
    """Stream orchestrator response, printing chunks as they arrive."""
    full_text = ""
    displayed = ""
    current_subagent = None

    async for event in orchestrator.stream_async(prompt):
        if "data" in event:
            full_text += event["data"]
            clean = re.sub(
                r"<thinking>.*?</thinking>", "", full_text, flags=re.DOTALL
            ).strip()
            if len(clean) > len(displayed):
                new = clean[len(displayed) :]
                console.print(new, end="", highlight=False)
                displayed = clean

        elif "current_tool_use" in event:
            tool_name = event["current_tool_use"].get("name", "")
            if tool_name and tool_name != current_subagent:
                current_subagent = tool_name
                display_name = tool_name.replace("_agent", "").replace("_", " ").title()
                console.print(f"\n[dim]⟶ {display_name}[/dim]", highlight=False)

    console.print()
    return displayed
