# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
X-Ray base service for IDP document trace analysis.

Provides reusable functions to retrieve and analyse AWS X-Ray tracing data for
a specific document, enabling pinpointing which step caused a problem.

This module is the *base* X-Ray service.  Additional functions for latency
percentiles, throttle analysis, and service performance summaries are added in
MR-03 (``cloudwatch_metrics_service.py`` and extensions to this file).

This module contains no ``@tool`` decorators and makes no assumptions about
agent frameworks.

Usage::

    from idp_common.monitoring.xray_service import (
        get_trace_for_document,
        analyze_trace,
        get_subsegment_details,
    )

    trace = get_trace_for_document(document_id, document_record)
    if trace:
        analysis = analyze_trace(trace["trace_id"])
"""

from __future__ import annotations

import json
import logging
import os
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

import boto3

logger = logging.getLogger(__name__)

# Default look-back window for X-Ray annotation queries
_DEFAULT_XRAY_LOOKBACK_HOURS: int = 24

# ---------------------------------------------------------------------------
# Module-level lazy boto3 client/resource cache
# ---------------------------------------------------------------------------
_xray_client: Optional[Any] = None
_dynamodb_resource: Optional[Any] = None


def _get_xray_client() -> Any:
    """Return (and lazily create) a module-level X-Ray boto3 client."""
    global _xray_client
    if _xray_client is None:
        _xray_client = boto3.client("xray")
    return _xray_client


def _get_dynamodb_resource() -> Any:
    """Return (and lazily create) a module-level DynamoDB boto3 resource."""
    global _dynamodb_resource
    if _dynamodb_resource is None:
        _dynamodb_resource = boto3.resource("dynamodb")
    return _dynamodb_resource


# Named constant for the tracking table sort key to avoid a magic string
# literal scattered through the code.  The tracking table uses a single-item
# partition design where the document metadata record is stored with a sentinel
# sort key value.
_TRACKING_TABLE_SK: str = "none"


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def get_trace_for_document(
    document_id: str,
    document_record: Optional[Dict[str, Any]] = None,
    lookback_hours: int = _DEFAULT_XRAY_LOOKBACK_HOURS,
) -> Optional[Dict[str, Any]]:
    """
    Find the X-Ray trace for a document and return basic trace metadata.

    Lookup order:
    1. ``TraceId`` field in *document_record* (cheapest — no API call)
    2. DynamoDB tracking table lookup via ``TRACKING_TABLE_NAME`` env var
    3. X-Ray annotation query (``annotation.document_id = "<document_id>"``)

    Args:
        document_id:     Document S3 object key / filename.
        document_record: Optional raw DynamoDB item.  If ``TraceId`` is
                         present the other lookup steps are skipped.
        lookback_hours:  How far back to search in X-Ray (step 3 only).

    Returns:
        ``{"trace_id": str, "source": str}`` where *source* is one of
        ``"document_record"``, ``"dynamodb"``, or ``"xray_annotation"``.
        Returns ``None`` if no trace is found.
    """
    # Step 1: from the document record passed in
    if document_record:
        trace_id = document_record.get("TraceId", "")
        if trace_id:
            logger.debug(
                "Trace ID %s found in document_record for %s", trace_id, document_id
            )
            return {"trace_id": trace_id, "source": "document_record"}

    # Step 2: DynamoDB lookup
    trace_id = _get_trace_id_from_dynamodb(document_id)
    if trace_id:
        return {"trace_id": trace_id, "source": "dynamodb"}

    # Step 3: X-Ray annotation query
    trace_id = _get_trace_id_from_xray_annotations(document_id, lookback_hours)
    if trace_id:
        return {"trace_id": trace_id, "source": "xray_annotation"}

    logger.info("No X-Ray trace found for document '%s'", document_id)
    return None


def analyze_trace(trace_id: str) -> Dict[str, Any]:
    """
    Retrieve and analyse an X-Ray trace, returning a structured summary.

    Args:
        trace_id: X-Ray trace ID.

    Returns:
        ``{
            "trace_id": str,
            "total_segments": int,
            "total_duration_ms": float,
            "error_segments": list[dict],   # segments with error or fault
            "slow_segments": list[dict],    # segments exceeding slow_threshold_ms
            "service_timeline": list[dict], # chronologically sorted services
            "has_performance_issues": bool,
        }``
        Returns a dict with ``"error"`` key if the trace cannot be retrieved.
    """
    segments = _get_trace_segments(trace_id)
    if not segments:
        return {
            "trace_id": trace_id,
            "error": f"No segments found for trace {trace_id}",
            "total_segments": 0,
            "total_duration_ms": 0.0,
            "error_segments": [],
            "slow_segments": [],
            "service_timeline": [],
            "has_performance_issues": False,
        }

    # Parse segment documents
    parsed = _parse_segment_documents(segments)
    analysis = _analyse_parsed_segments(parsed)
    timeline = _build_service_timeline(parsed)

    return {
        "trace_id": trace_id,
        "total_segments": analysis["total_segments"],
        "total_duration_ms": analysis["total_duration_ms"],
        "error_segments": analysis["error_segments"],
        "slow_segments": analysis["slow_segments"],
        "service_timeline": timeline,
        "has_performance_issues": analysis["has_performance_issues"],
    }


def get_subsegment_details(
    trace_id: str,
    service_name: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """
    Return a flat list of all subsegments within a trace, optionally filtered.

    Recursively walks the subsegment tree and returns each subsegment as a
    plain dict with ``name``, ``duration_ms``, ``has_error``, and
    ``origin`` fields.

    Args:
        trace_id:     X-Ray trace ID.
        service_name: If provided, return only subsegments whose ``name``
                      contains this string (case-insensitive).

    Returns:
        List of subsegment dicts, sorted by ``start_time`` ascending.
    """
    segments = _get_trace_segments(trace_id)
    if not segments:
        return []

    all_subsegments: List[Dict[str, Any]] = []
    for raw_segment in segments:
        doc = _parse_segment_document(raw_segment.get("Document", {}))
        if doc:
            _collect_subsegments(doc, all_subsegments)

    # Filter by service name if requested
    if service_name:
        lower = service_name.lower()
        all_subsegments = [
            s for s in all_subsegments if lower in s.get("name", "").lower()
        ]

    # Sort chronologically
    all_subsegments.sort(key=lambda s: s.get("start_time", 0))
    return all_subsegments


def extract_lambda_request_ids(xray_trace_id: str) -> Dict[str, str]:
    """
    Extract Lambda request IDs from an X-Ray trace.

    Returns a mapping of Lambda function name → CloudWatch request ID,
    which can be used to correlate CW log streams with a specific document
    processing execution.

    Args:
        xray_trace_id: X-Ray trace ID.

    Returns:
        ``{function_name: request_id}`` dict.  Empty if no trace found.
    """
    logger.info("Extracting Lambda request IDs from X-Ray trace %s", xray_trace_id)
    xray_client = _get_xray_client()

    try:
        response = xray_client.batch_get_traces(TraceIds=[xray_trace_id])
        traces = response.get("Traces", [])
        if not traces:
            logger.warning("No traces found for trace ID: %s", xray_trace_id)
            return {}

        result: Dict[str, str] = {}
        for trace in traces:
            for segment in trace.get("Segments", []):
                try:
                    doc = json.loads(segment["Document"])
                except (json.JSONDecodeError, KeyError):
                    continue
                for execution in _parse_segment_for_lambda(doc):
                    fname = execution.get("function_name", "")
                    rid = execution.get("request_id", "")
                    if fname and rid:
                        result[fname] = rid

        logger.info("Lambda function → request ID map: %s", result)
        return result

    except Exception as exc:  # noqa: BLE001
        logger.error(
            "Error extracting Lambda request IDs from trace %s: %s",
            xray_trace_id,
            exc,
        )
        return {}


# ---------------------------------------------------------------------------
# Private helpers — trace retrieval
# ---------------------------------------------------------------------------


def _get_trace_id_from_dynamodb(document_id: str) -> Optional[str]:
    """Look up the trace ID in the DynamoDB tracking table."""
    table_name = os.environ.get("TRACKING_TABLE_NAME", "")
    if not table_name:
        return None

    try:
        dynamodb = _get_dynamodb_resource()
        table = dynamodb.Table(table_name)  # type: ignore[attr-defined]
        response = table.get_item(
            Key={"PK": f"doc#{document_id}", "SK": _TRACKING_TABLE_SK}
        )
        if "Item" in response:
            trace_id = response["Item"].get("TraceId")
            if trace_id:
                logger.debug(
                    "TraceId %s found in DynamoDB for %s", trace_id, document_id
                )
                return trace_id
    except Exception as exc:  # noqa: BLE001
        logger.warning("DynamoDB trace lookup failed for %s: %s", document_id, exc)

    return None


def _get_trace_id_from_xray_annotations(
    document_id: str,
    lookback_hours: int = _DEFAULT_XRAY_LOOKBACK_HOURS,
) -> Optional[str]:
    """Query X-Ray annotations to find a trace for the document."""
    logger.info("Searching X-Ray annotations for document_id '%s'", document_id)
    try:
        xray_client = _get_xray_client()
        end_time = datetime.now(timezone.utc)
        start_time = end_time - timedelta(hours=lookback_hours)

        response = xray_client.get_trace_summaries(
            StartTime=start_time,
            EndTime=end_time,
            FilterExpression=f'annotation.document_id = "{document_id}"',
        )
        traces = response.get("TraceSummaries", [])
        if traces:
            # Sort by ResponseTime descending to get the most recent trace
            # (covers the case where a document has been reprocessed/retried)
            traces_sorted = sorted(
                traces,
                key=lambda t: t.get("ResponseTime", 0),
                reverse=True,
            )
            trace_id = traces_sorted[0].get("Id")
            logger.info(
                "Found trace %s via X-Ray annotation for %s", trace_id, document_id
            )
            return trace_id
    except Exception as exc:  # noqa: BLE001
        logger.warning("X-Ray annotation query failed for %s: %s", document_id, exc)

    return None


def _get_trace_segments(trace_id: str) -> List[Dict[str, Any]]:
    """Fetch raw segment dicts for a trace from X-Ray."""
    try:
        xray_client = _get_xray_client()
        response = xray_client.batch_get_traces(TraceIds=[trace_id])
        traces = response.get("Traces", [])
        if not traces:
            logger.info("No trace data found for trace_id %s", trace_id)
            return []
        return traces[0].get("Segments", [])
    except Exception as exc:  # noqa: BLE001
        logger.warning("Failed to fetch trace segments for %s: %s", trace_id, exc)
        return []


# ---------------------------------------------------------------------------
# Private helpers — segment parsing
# ---------------------------------------------------------------------------


def _parse_segment_document(doc: Any) -> Dict[str, Any]:
    """Parse a segment document that may be a JSON string or a dict."""
    if isinstance(doc, str):
        try:
            return json.loads(doc)
        except json.JSONDecodeError:
            return {}
    return doc or {}


def _parse_segment_documents(
    raw_segments: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    """Return a list of parsed segment document dicts."""
    parsed = []
    for seg in raw_segments:
        doc = _parse_segment_document(seg.get("Document", {}))
        if doc:
            parsed.append(doc)
    return parsed


def _analyse_parsed_segments(
    parsed_docs: List[Dict[str, Any]],
    slow_threshold_ms: float = 5000.0,
) -> Dict[str, Any]:
    """
    Analyse parsed segment documents and return error/slow segment summaries.

    Args:
        parsed_docs:       List of parsed segment document dicts.
        slow_threshold_ms: Duration threshold in ms above which a segment is
                           considered slow (default: 5000 ms / 5 s).
    """
    total_duration = 0.0
    error_segments: List[Dict[str, Any]] = []
    slow_segments: List[Dict[str, Any]] = []

    for doc in parsed_docs:
        start = doc.get("start_time", 0.0)
        end = doc.get("end_time", 0.0)
        duration_ms = (end - start) * 1000
        total_duration += end - start

        if doc.get("error") or doc.get("fault"):
            cause = doc.get("cause", {})
            exceptions = cause.get("exceptions", []) if isinstance(cause, dict) else []
            error_segments.append(
                {
                    "id": doc.get("id", ""),
                    "name": doc.get("name", ""),
                    "error": doc.get("error"),
                    "fault": doc.get("fault"),
                    "cause": exceptions,
                }
            )

        if duration_ms > slow_threshold_ms:
            slow_segments.append(
                {
                    "id": doc.get("id", ""),
                    "name": doc.get("name", ""),
                    "duration_ms": round(duration_ms, 1),
                    "origin": doc.get("origin", ""),
                }
            )

    return {
        "total_segments": len(parsed_docs),
        "total_duration_ms": round(total_duration * 1000, 1),
        "error_segments": error_segments,
        "slow_segments": slow_segments,
        "has_performance_issues": bool(slow_segments or error_segments),
    }


def _build_service_timeline(
    parsed_docs: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    """Build a chronologically sorted service timeline from parsed segment docs."""
    timeline = []
    for doc in parsed_docs:
        start = doc.get("start_time", 0.0)
        end = doc.get("end_time", 0.0)
        timeline.append(
            {
                "service_name": doc.get("name", ""),
                "origin": doc.get("origin", ""),
                "start_time": start,
                "end_time": end,
                "duration_ms": round((end - start) * 1000, 1),
                "has_error": bool(doc.get("error") or doc.get("fault")),
                "annotations": doc.get("annotations", {}),
            }
        )
    return sorted(timeline, key=lambda x: x.get("start_time", 0))


def _collect_subsegments(
    doc: Dict[str, Any],
    result: List[Dict[str, Any]],
) -> None:
    """Recursively collect all subsegments from a segment document."""
    for sub in doc.get("subsegments", []):
        start = sub.get("start_time", 0.0)
        end = sub.get("end_time", 0.0)
        result.append(
            {
                "name": sub.get("name", ""),
                "origin": sub.get("origin", ""),
                "start_time": start,
                "end_time": end,
                "duration_ms": round((end - start) * 1000, 1),
                "has_error": bool(sub.get("error") or sub.get("fault")),
                "has_throttle": bool(sub.get("throttle")),
                "namespace": sub.get("namespace", ""),
                "aws": sub.get("aws", {}),
            }
        )
        _collect_subsegments(sub, result)


def _parse_segment_for_lambda(
    segment: Dict[str, Any],
) -> List[Dict[str, Any]]:
    """
    Recursively parse a segment document for Lambda execution entries.

    Returns a list of ``{"function_name": str, "request_id": str}`` dicts.
    """
    results: List[Dict[str, Any]] = []

    if segment.get("origin") in ("AWS::Lambda", "AWS::Lambda::Function"):
        aws_info = segment.get("aws", {})
        function_name = segment.get("name", "Unknown")
        # The ARN-based name is more precise when available
        if "resource_arn" in segment:
            function_name = segment["resource_arn"].split(":")[-1]
        request_id = aws_info.get("request_id", "")
        results.append({"function_name": function_name, "request_id": request_id})

    for sub in segment.get("subsegments", []):
        results.extend(_parse_segment_for_lambda(sub))

    return results
