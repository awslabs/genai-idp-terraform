# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Factory for creating IDP agents.
"""

from typing import Any, Callable, Dict, List

from ..common.idp_agent import IDPAgent


class IDPAgentFactory:
    """Factory for creating and managing IDP agents."""

    def __init__(self):
        """Initialize the factory with an empty registry."""
        self._registry: Dict[str, Dict[str, Any]] = {}

    def register_agent(
        self,
        agent_id: str,
        agent_name: str,
        agent_description: str,
        creator_func: Callable[
            ..., Any
        ],  # Now returns Strands Agent instead of IDPAgent
        sample_queries: List[str] = None,
    ) -> None:
        """
        Register an agent creator function with metadata.

        Args:
            agent_id: Unique identifier for the agent
            agent_name: Human-readable name for the agent
            agent_description: Description of what the agent does
            creator_func: Function that creates and returns a Strands Agent instance
            sample_queries: List of example queries for the agent
        """
        self._registry[agent_id] = {
            "agent_name": agent_name,
            "agent_description": agent_description,
            "creator_func": creator_func,
            "sample_queries": sample_queries or [],
        }

    def list_available_agents(self) -> List[Dict[str, str]]:
        """
        List all available agents with their metadata.

        Returns:
            List of dicts containing agent_id, agent_name, agent_description, and sample_queries
        """
        return [
            {
                "agent_id": agent_id,
                "agent_name": info["agent_name"],
                "agent_description": info["agent_description"],
                "sample_queries": info["sample_queries"],
            }
            for agent_id, info in self._registry.items()
        ]

    def create_agent(self, agent_id: str, **kwargs) -> IDPAgent:
        """
        Create an agent instance by ID.

        Args:
            agent_id: The ID of the agent to create
            **kwargs: Arguments to pass to the agent creator function

        Returns:
            IDPAgent instance with registered metadata

        Raises:
            ValueError: If agent_id is not registered
        """
        if agent_id not in self._registry:
            raise ValueError(f"Agent ID '{agent_id}' not found in registry")

        info = self._registry[agent_id]
        creator_func = info["creator_func"]

        # Call creator function which now returns a Strands agent
        result = creator_func(**kwargs)

        # Handle different return formats from creator functions
        if isinstance(result, tuple):
            # External MCP agent returns (strands_agent, mcp_client)
            strands_agent, mcp_client = result
        else:
            # Other agents return just the strands_agent
            strands_agent = result
            mcp_client = None

        # Wrap it in IDPAgent with the registered metadata
        return IDPAgent(
            agent=strands_agent,
            agent_id=agent_id,
            agent_name=info["agent_name"],
            agent_description=info["agent_description"],
            sample_queries=info["sample_queries"],
            job_id=kwargs.get("job_id"),
            user_id=kwargs.get("user_id"),
            mcp_client=mcp_client,
        )

    def create_orchestrator_agent(self, agent_ids: List[str], **kwargs) -> IDPAgent:
        """
        Create an orchestrator agent that can route queries to multiple specialized agents.

        Args:
            agent_ids: List of agent IDs to include as tools in the orchestrator
            **kwargs: Arguments to pass to the orchestrator and specialized agents

        Returns:
            IDPAgent instance configured as an orchestrator

        Raises:
            ValueError: If any agent_id is not registered
        """
        # Validate all agent IDs exist
        for agent_id in agent_ids:
            if agent_id not in self._registry:
                raise ValueError(f"Agent ID '{agent_id}' not found in registry")

        # Import orchestrator here to avoid circular imports
        from ..orchestrator.agent import create_orchestrator_agent

        # Create the orchestrator agent
        orchestrator_agent = create_orchestrator_agent(agent_ids=agent_ids, **kwargs)

        # Create orchestrator metadata
        agent_names = [self._registry[aid]["agent_name"] for aid in agent_ids]
        orchestrator_description = (
            f"Orchestrator agent that routes queries to: {', '.join(agent_names)}"
        )

        # Wrap in IDPAgent
        return IDPAgent(
            agent=orchestrator_agent,
            agent_id=f"orchestrator-{'-'.join(agent_ids)}",
            agent_name="Orchestrator Agent",
            agent_description=orchestrator_description,
            sample_queries=[],
            job_id=kwargs.get("job_id"),
            user_id=kwargs.get("user_id"),
        )
