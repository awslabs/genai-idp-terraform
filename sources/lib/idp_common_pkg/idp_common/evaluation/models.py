# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Models for document evaluation.

This module provides data models for evaluation results and comparison methods.
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional


class EvaluationMethod(Enum):
    """Evaluation method types for different field comparison approaches."""

    EXACT = "EXACT"  # Exact string match after stripping punctuation and whitespace
    NUMERIC_EXACT = "NUMERIC_EXACT"  # Exact numeric match after normalizing
    SEMANTIC = "SEMANTIC"  # Semantic similarity comparison using embeddings
    HUNGARIAN = "HUNGARIAN"  # Bipartite matching for lists of values
    FUZZY = "FUZZY"  # Fuzzy string matching
    LLM = "LLM"  # LLM-based comparison using Bedrock models


@dataclass
class EvaluationAttribute:
    """Configuration for a single attribute to be evaluated."""

    name: str
    description: str
    evaluation_method: EvaluationMethod = EvaluationMethod.EXACT
    evaluation_threshold: float = 0.8  # Used for SEMANTIC, and FUZZY methods
    comparator_type: Optional[str] = None  # Used for HUNGARIAN method


@dataclass
class AttributeEvaluationResult:
    """Result of evaluation for a single attribute."""

    name: str
    expected: Any
    actual: Any
    matched: bool
    score: float = 1.0  # Score between 0 and 1 for fuzzy matching methods
    reason: Optional[str] = None  # Explanation from LLM evaluation
    error_details: Optional[str] = None
    evaluation_method: str = "EXACT"
    evaluation_threshold: Optional[float] = None
    comparator_type: Optional[str] = None  # Used for HUNGARIAN methods
    confidence: Optional[float] = (
        None  # Confidence score from assessment for actual values
    )
    confidence_threshold: Optional[float] = (
        None  # Confidence threshold from assessment for actual values
    )
    weight: Optional[float] = (
        None  # Field importance weight from Stickler (business criticality)
    )


@dataclass
class SectionEvaluationResult:
    """Result of evaluation for a document section."""

    section_id: str
    document_class: str
    attributes: List[AttributeEvaluationResult]
    metrics: Dict[str, float] = field(default_factory=dict)

    def get_attribute_results(self) -> Dict[str, AttributeEvaluationResult]:
        """Get results indexed by attribute name."""
        return {attr.name: attr for attr in self.attributes}


@dataclass
class DocSplitMetrics:
    """Document split classification accuracy metrics."""

    page_level_accuracy: float
    split_accuracy_without_order: float
    split_accuracy_with_order: float
    total_pages: int
    total_splits: int
    correctly_classified_pages: int
    correctly_split_without_order: int
    correctly_split_with_order: int
    page_details: List[Dict[str, Any]] = field(default_factory=list)
    section_details_without_order: List[Dict[str, Any]] = field(default_factory=list)
    section_details_with_order: List[Dict[str, Any]] = field(default_factory=list)
    predicted_sections: List[Dict[str, Any]] = field(
        default_factory=list
    )  # All predicted sections for unmatched display
    errors: List[str] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary representation."""
        return {
            "page_level_accuracy": self.page_level_accuracy,
            "split_accuracy_without_order": self.split_accuracy_without_order,
            "split_accuracy_with_order": self.split_accuracy_with_order,
            "total_pages": self.total_pages,
            "total_splits": self.total_splits,
            "correctly_classified_pages": self.correctly_classified_pages,
            "correctly_split_without_order": self.correctly_split_without_order,
            "correctly_split_with_order": self.correctly_split_with_order,
            "page_details": self.page_details,
            "section_details_without_order": self.section_details_without_order,
            "section_details_with_order": self.section_details_with_order,
            "predicted_sections": self.predicted_sections,
            "errors": self.errors,
        }


@dataclass
class DocumentEvaluationResult:
    """Comprehensive evaluation result for a document."""

    document_id: str
    section_results: List[SectionEvaluationResult]
    overall_metrics: Dict[str, float] = field(default_factory=dict)
    execution_time: float = 0.0
    output_uri: Optional[str] = None
    doc_split_metrics: Optional[DocSplitMetrics] = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary representation."""
        result = {
            "document_id": self.document_id,
            "overall_metrics": self.overall_metrics,
            "execution_time": self.execution_time,
            "output_uri": self.output_uri,
            "section_results": [
                {
                    "section_id": sr.section_id,
                    "document_class": sr.document_class,
                    "metrics": sr.metrics,
                    "attributes": [
                        {
                            "name": ar.name,
                            "expected": ar.expected,
                            "actual": ar.actual,
                            "matched": ar.matched,
                            "score": ar.score,
                            "reason": ar.reason,
                            "error_details": ar.error_details,
                            "evaluation_method": ar.evaluation_method,
                            "evaluation_threshold": ar.evaluation_threshold,
                            "comparator_type": ar.comparator_type,
                            "confidence": ar.confidence,
                            "confidence_threshold": ar.confidence_threshold,
                            "weight": ar.weight,
                        }
                        for ar in sr.attributes
                    ],
                }
                for sr in self.section_results
            ],
        }

        # Add doc_split_metrics if available
        if self.doc_split_metrics:
            result["doc_split_metrics"] = self.doc_split_metrics.to_dict()

        return result

    def to_markdown(self) -> str:
        """Convert evaluation results to markdown format."""
        sections = []

        # Add main title at the very beginning
        sections.append("# Evaluation Report")
        sections.append("")

        # Get overall stats for visual summary
        total_attributes = 0
        matched_attributes = 0
        for sr in self.section_results:
            for attr in sr.attributes:
                total_attributes += 1
                if attr.matched:
                    matched_attributes += 1

        match_rate = (
            matched_attributes / total_attributes if total_attributes > 0 else 0
        )
        precision = self.overall_metrics.get("precision", 0)
        recall = self.overall_metrics.get("recall", 0)
        f1_score = self.overall_metrics.get("f1_score", 0)

        # Create unified summary with both extraction and doc split metrics
        sections.append("## Summary")
        sections.append("")

        # Add doc split metrics FIRST if available
        if self.doc_split_metrics:

            def get_indicator(accuracy: float) -> str:
                if accuracy >= 0.9:
                    return "🟢"
                elif accuracy >= 0.7:
                    return "🟡"
                elif accuracy >= 0.5:
                    return "🟠"
                else:
                    return "🔴"

            page_acc = self.doc_split_metrics.page_level_accuracy
            split_no_ord_acc = self.doc_split_metrics.split_accuracy_without_order
            split_ord_acc = self.doc_split_metrics.split_accuracy_with_order

            # Create progress bars
            page_percent = int(page_acc * 100)
            page_progress = f"[{'█' * (page_percent // 5)}{'░' * (20 - page_percent // 5)}] {page_percent}%"

            split_no_ord_percent = int(split_no_ord_acc * 100)
            split_no_ord_progress = f"[{'█' * (split_no_ord_percent // 5)}{'░' * (20 - split_no_ord_percent // 5)}] {split_no_ord_percent}%"

            split_ord_percent = int(split_ord_acc * 100)
            split_ord_progress = f"[{'█' * (split_ord_percent // 5)}{'░' * (20 - split_ord_percent // 5)}] {split_ord_percent}%"

            sections.append("**Document Split Classification:**")
            sections.append(
                f"- **Page Level Accuracy**: {get_indicator(page_acc)} "
                f"{self.doc_split_metrics.correctly_classified_pages}/{self.doc_split_metrics.total_pages} pages "
                f"{page_progress}"
            )
            sections.append(
                f"- **Split Accuracy (Without Order)**: {get_indicator(split_no_ord_acc)} "
                f"{self.doc_split_metrics.correctly_split_without_order}/{self.doc_split_metrics.total_splits} sections "
                f"{split_no_ord_progress}"
            )
            sections.append(
                f"- **Split Accuracy (With Order)**: {get_indicator(split_ord_acc)} "
                f"{self.doc_split_metrics.correctly_split_with_order}/{self.doc_split_metrics.total_splits} sections "
                f"{split_ord_progress}"
            )
            sections.append("")

        # Then add extraction metrics
        sections.append("**Document Extraction:**")

        # Match rate indicator
        if match_rate >= 0.9:
            match_indicator = "🟢"
        elif match_rate >= 0.7:
            match_indicator = "🟡"
        elif match_rate >= 0.5:
            match_indicator = "🟠"
        else:
            match_indicator = "🔴"

        # F1 score indicator
        if f1_score >= 0.9:
            f1_indicator = "🟢"
        elif f1_score >= 0.7:
            f1_indicator = "🟡"
        elif f1_score >= 0.5:
            f1_indicator = "🟠"
        else:
            f1_indicator = "🔴"

        # Create a visual progress bar for match rate
        match_percent = int(match_rate * 100)
        progress_bar = f"[{'█' * (match_percent // 5)}{'░' * (20 - match_percent // 5)}] {match_percent}%"

        sections.append(
            f"- **Match Rate**: {match_indicator} {matched_attributes}/{total_attributes} attributes matched {progress_bar}"
        )
        sections.append(
            f"- **Precision**: {precision:.2f} | **Recall**: {recall:.2f} | **F1 Score**: {f1_indicator} {f1_score:.2f}"
        )

        # Add weighted overall score if available
        weighted_score = self.overall_metrics.get("weighted_overall_score", 0)
        if weighted_score >= 0.9:
            weighted_indicator = "🟢"
        elif weighted_score >= 0.7:
            weighted_indicator = "🟡"
        elif weighted_score >= 0.5:
            weighted_indicator = "🟠"
        else:
            weighted_indicator = "🔴"

        sections.append(
            f"- **Weighted Overall Score**: {weighted_indicator} {weighted_score:.4f} (Stickler's field-weighted aggregate)"
        )

        sections.append("")

        # Add overall metrics with two separate tables
        sections.append("## Overall Metrics")
        sections.append("")

        # Helper function for rating
        def get_rating_for_metric(metric_name: str, value: float) -> str:
            if metric_name in [
                "precision",
                "recall",
                "f1_score",
                "accuracy",
                "weighted_overall_score",
                "page_level_accuracy",
                "split_accuracy_without_order",
                "split_accuracy_with_order",
            ]:
                if value >= 0.9:
                    return "🟢 Excellent"
                elif value >= 0.7:
                    return "🟡 Good"
                elif value >= 0.5:
                    return "🟠 Fair"
                else:
                    return "🔴 Poor"
            elif metric_name in ["false_alarm_rate", "false_discovery_rate"]:
                # For error metrics, lower is better
                if value <= 0.1:
                    return "🟢 Excellent"
                elif value <= 0.3:
                    return "🟡 Good"
                elif value <= 0.5:
                    return "🟠 Fair"
                else:
                    return "🔴 Poor"
            else:
                return ""  # No rating for other metrics

        # Add doc split metrics table first if available
        if self.doc_split_metrics:
            sections.append("### Document Split Classification Metrics")
            doc_split_table = (
                "| Metric | Value | Rating |\n| ------ | :----: | :----: |\n"
            )
            doc_split_table += f"| page_level_accuracy | {self.doc_split_metrics.page_level_accuracy:.4f} | {get_rating_for_metric('page_level_accuracy', self.doc_split_metrics.page_level_accuracy)} |\n"
            doc_split_table += f"| split_accuracy_without_order | {self.doc_split_metrics.split_accuracy_without_order:.4f} | {get_rating_for_metric('split_accuracy_without_order', self.doc_split_metrics.split_accuracy_without_order)} |\n"
            doc_split_table += f"| split_accuracy_with_order | {self.doc_split_metrics.split_accuracy_with_order:.4f} | {get_rating_for_metric('split_accuracy_with_order', self.doc_split_metrics.split_accuracy_with_order)} |\n"
            sections.append(doc_split_table)
            sections.append("")

        # Add extraction metrics table
        sections.append("### Document Extraction Metrics")
        extraction_table = "| Metric | Value | Rating |\n| ------ | :----: | :----: |\n"
        for metric, value in self.overall_metrics.items():
            indicator = get_rating_for_metric(metric, value)
            extraction_table += f"| {metric} | {value:.4f} | {indicator} |\n"
        sections.append(extraction_table)
        sections.append("")

        # Add doc split analysis tables if available (right after Overall Metrics)
        if self.doc_split_metrics:
            # Combined Section split analysis
            sections.append("## 📑 Section Split Analysis")
            sections.append("")

            if (
                self.doc_split_metrics.section_details_without_order
                or self.doc_split_metrics.section_details_with_order
            ):
                sections.append(
                    "| Section Match | Page Order Match | Section ID | Expected Class | Expected Pages | Pred Class | Pred Pages | Matched Section |"
                )
                sections.append(
                    "| :-----------: | :--------------: | ---------- | -------------- | -------------- | ---------- | ---------- | --------------- |"
                )

                # Track matched predicted section IDs
                matched_pred_section_ids = set()

                # Get list of all predicted sections from service.py
                # We need to identify unmatched predicted sections
                # We'll collect matched IDs first, then show unmatched ones at the end

                # Combine data from both metrics for ground truth sections
                for idx, section_with_order in enumerate(
                    self.doc_split_metrics.section_details_with_order
                ):
                    # Get corresponding section from split_no_order
                    section_no_order = (
                        self.doc_split_metrics.section_details_without_order[idx]
                        if idx
                        < len(self.doc_split_metrics.section_details_without_order)
                        else None
                    )

                    # Section Match status (from split_no_order)
                    section_match = (
                        "✅"
                        if section_no_order and section_no_order["matched"]
                        else "❌"
                    )

                    # Page Order Match status (from split_with_order)
                    page_order_match = (
                        "✅" if section_with_order.get("order_matched", False) else "❌"
                    )

                    gt_pages = str(section_with_order["ground_truth_pages"])
                    pred_pages = (
                        str(section_with_order["predicted_pages"])
                        if section_with_order["predicted_pages"]
                        else "N/A"
                    )
                    matched_id = (
                        section_with_order["matched_section_id"]
                        if section_with_order["matched_section_id"]
                        else "N/A"
                    )

                    # Track matched predicted section IDs
                    if section_with_order["matched_section_id"]:
                        matched_pred_section_ids.add(
                            section_with_order["matched_section_id"]
                        )

                    sections.append(
                        f"| {section_match} | {page_order_match} | {section_with_order['section_id']} | "
                        f"{section_with_order['ground_truth_class']} | {gt_pages} | {section_with_order['predicted_class']} | "
                        f"{pred_pages} | {matched_id} |"
                    )

                # Add unmatched predicted sections
                for pred_section in self.doc_split_metrics.predicted_sections:
                    if pred_section["section_id"] not in matched_pred_section_ids:
                        pred_pages = str(pred_section["page_indices"])
                        sections.append(
                            f"| ❌ | ❌ | N/A | No Match | N/A | "
                            f"{pred_section['document_class']} | {pred_pages} | {pred_section['section_id']} |"
                        )
            else:
                sections.append("*No section data available*")

            sections.append("")

            # Add errors if any
            if self.doc_split_metrics.errors:
                sections.append("### ⚠️ Doc Split Errors")
                sections.append("")
                for error in self.doc_split_metrics.errors:
                    sections.append(f"- {error}")
                sections.append("")

        # Add header for extraction attribute evaluation section
        sections.append("## Extraction Attribute Evaluation")
        sections.append("")

        # Add section results
        for sr in self.section_results:
            sections.append(f"### Section: {sr.section_id} ({sr.document_class})")

            # Check if this section had an evaluation failure
            if sr.metrics.get("evaluation_failed", False):
                sections.append("")
                sections.append("⚠️ **EVALUATION FAILED**")
                sections.append("")
                sections.append(
                    f"This section could not be evaluated because no configuration was found for document class: **{sr.document_class}**"
                )
                sections.append("")
                sections.append("**Reasons for failure:**")
                sections.append(
                    "- No schema configuration exists for this document class in your evaluation config"
                )
                sections.append(
                    "- No baseline data was provided to auto-generate a schema"
                )
                sections.append("")
                sections.append("**Impact:**")
                sections.append(
                    "- This section contributes **zero accuracy** to all metrics (precision, recall, F1, etc.)"
                )
                sections.append(
                    "- The failure is reflected in document-level aggregate metrics"
                )
                sections.append("")
                sections.append("**How to fix:**")
                sections.append(
                    f"1. Add a configuration for '{sr.document_class}' in your `evaluation` config YAML"
                )
                sections.append(
                    "2. Ensure the document class name matches exactly (case-insensitive)"
                )
                sections.append(
                    "3. Or provide baseline/expected data when calling evaluate_document() to enable auto-generation"
                )
                sections.append("")

                # Show the failure reason from attributes if available
                if sr.attributes and sr.attributes[0].reason:
                    sections.append("**Detailed error:**")
                    sections.append(f"```\n{sr.attributes[0].reason}\n```")
                    sections.append("")

                # Still show the metrics (all zeros) for transparency
                sections.append("### Metrics (Failure State)")
                metrics_table = (
                    "| Metric | Value | Rating |\n| ------ | :----: | :----: |\n"
                )
                for metric, value in sr.metrics.items():
                    if metric == "evaluation_failed":
                        continue  # Skip the flag itself in the table
                    metrics_table += f"| {metric} | {value:.4f} | ❌ Failed |\n"
                sections.append(metrics_table)
                sections.append("")
                continue  # Skip attribute display for failed sections

            # Section metrics with enhanced formatting (normal case)
            sections.append("#### Metrics")
            metrics_table = (
                "| Metric | Value | Rating |\n| ------ | :----: | :----: |\n"
            )
            for metric, value in sr.metrics.items():
                # Skip the evaluation_failed flag in normal display
                if metric == "evaluation_failed":
                    continue

                # Add a visual indicator based on metric value
                if metric in [
                    "precision",
                    "recall",
                    "f1_score",
                    "accuracy",
                    "weighted_overall_score",
                ]:
                    if value >= 0.9:
                        indicator = "🟢 Excellent"
                    elif value >= 0.7:
                        indicator = "🟡 Good"
                    elif value >= 0.5:
                        indicator = "🟠 Fair"
                    else:
                        indicator = "🔴 Poor"
                elif metric in ["false_alarm_rate", "false_discovery_rate"]:
                    # For error metrics, lower is better
                    if value <= 0.1:
                        indicator = "🟢 Excellent"
                    elif value <= 0.3:
                        indicator = "🟡 Good"
                    elif value <= 0.5:
                        indicator = "🟠 Fair"
                    else:
                        indicator = "🔴 Poor"
                else:
                    indicator = ""  # No rating for other metrics

                metrics_table += f"| {metric} | {value:.4f} | {indicator} |\n"
            sections.append(metrics_table)
            sections.append("")

            # Attribute results
            sections.append("#### Attributes")
            attr_table = "| Status | Attribute | Expected | Actual | Confidence | Confidence Threshold | Score | Weight | Method | Reason |\n"
            attr_table += "| :----: | --------- | -------- | ------ | :---------------: | :---------------: | ----- | :----: | ------ | ------ |\n"
            for ar in sr.attributes:
                expected = str(ar.expected).replace("\n", " ")
                actual = str(ar.actual).replace("\n", " ")
                # Don't truncate the reason field for the report
                reason = str(ar.reason).replace("\n", " ") if ar.reason else ""

                # Use evaluation_method directly - it's already formatted with threshold
                method_display = ar.evaluation_method

                # Add color-coded status symbols (will render in markdown-compatible viewers)
                if ar.matched:
                    # Green checkmark for matched
                    status_symbol = "✅"
                else:
                    # Red X for not matched
                    status_symbol = "❌"

                # Format confidence values
                confidence_str = (
                    f"{ar.confidence:.2f}" if ar.confidence is not None else "N/A"
                )

                # Format confidence threshold values
                threshold_str = (
                    f"{ar.confidence_threshold:.2f}"
                    if ar.confidence_threshold is not None
                    else "N/A"
                )

                # Format weight value (defaults to 1.0 if not specified)
                weight_str = f"{ar.weight:.2f}" if ar.weight is not None else "1.00"

                attr_table += f"| {status_symbol} | {ar.name} | {expected} | {actual} | {confidence_str} | {threshold_str} | {ar.score:.2f} | {weight_str} | {method_display} | {reason} |\n"
            sections.append(attr_table)
            sections.append("")

        # Add execution time
        sections.append(f"Execution time: {self.execution_time:.2f} seconds")

        # Add evaluation methods explanation
        sections.append("")
        sections.append("## Evaluation Methods Used")
        sections.append("")
        sections.append(
            "This evaluation uses Stickler-based comparison with the following methods:"
        )
        sections.append("")
        sections.append("### Field-Level Comparison Methods")
        sections.append("")
        sections.append("1. **EXACT** - Exact string match (case-sensitive)")
        sections.append(
            "   - Use for: IDs, codes, exact text requiring character-for-character match"
        )
        sections.append("")
        sections.append(
            "2. **NUMERIC_EXACT** - Numeric comparison with configurable tolerance"
        )
        sections.append("   - Tolerance specified via `x-aws-idp-evaluation-threshold`")
        sections.append("   - Use for: Monetary amounts, percentages, numeric values")
        sections.append("")
        sections.append("3. **FUZZY** - Fuzzy string matching using similarity metrics")
        sections.append(
            "   - Threshold specified via `x-aws-idp-evaluation-threshold` (0.0-1.0)"
        )
        sections.append("   - Use for: Names, addresses, text with minor variations")
        sections.append("")
        sections.append(
            "4. **LEVENSHTEIN** - Levenshtein distance-based string comparison"
        )
        sections.append("   - Configurable threshold for acceptable edit distance")
        sections.append(
            "   - Use for: Similar to FUZZY but using specific edit distance algorithm"
        )
        sections.append("")
        sections.append("5. **SEMANTIC** - Semantic similarity using embedding models")
        sections.append("   - Threshold specified via `x-aws-idp-evaluation-threshold`")
        sections.append(
            "   - Use for: Text where meaning matters more than exact wording"
        )
        sections.append("")
        sections.append(
            "6. **LLM** - Advanced semantic evaluation using **AWS Bedrock LLMs**"
        )
        sections.append("   - Configured via `evaluation.llm_method` section:")
        sections.append("     - `model`: Bedrock model ID (e.g., Claude Haiku, Sonnet)")
        sections.append(
            "     - `task_prompt`: Custom prompt template with context placeholders"
        )
        sections.append("     - `system_prompt`: System instructions for the LLM")
        sections.append(
            "     - `temperature`, `top_k`, `top_p`, `max_tokens`: LLM generation parameters"
        )
        sections.append("   - Provides contextual evaluation with reasoning")
        sections.append(
            "   - Use for: Complex nested objects, structured data, semantic understanding"
        )
        sections.append("")
        sections.append("### Array-Level Matching")
        sections.append("")
        sections.append(
            "7. **HUNGARIAN** - Bipartite graph matching for arrays of structured objects"
        )
        sections.append(
            "   - Finds optimal 1:1 mapping between expected and actual lists"
        )
        sections.append(
            "   - Each matched item pair is then compared using field-level methods"
        )
        sections.append(
            '   - Configured with `x-aws-idp-evaluation-method: "HUNGARIAN"` on array properties'
        )
        sections.append("")
        sections.append(
            "8. **LLM for Arrays** - Semantic evaluation of entire list structures"
        )
        sections.append("   - Evaluates whether lists semantically match as a whole")
        sections.append(
            '   - Configured with `x-aws-idp-evaluation-method: "LLM"` on array properties'
        )
        sections.append("")
        sections.append("### Field Weighting")
        sections.append("")
        sections.append(
            "Fields can be assigned importance weights using `x-aws-stickler-weight` in the schema:"
        )
        sections.append("- **Default weight**: 1.0 (standard importance)")
        sections.append(
            "- **Higher weights** (e.g., 2.0, 3.0): Critical fields that matter more for overall quality"
        )
        sections.append(
            "- **Lower weights** (e.g., 0.5): Less important optional fields"
        )
        sections.append(
            "- **Impact**: Used in Stickler's weighted_overall_score calculation"
        )
        sections.append(
            "- **Display**: Shown in the Weight column of attribute results"
        )
        sections.append("")
        sections.append("**Example field weights:**")
        sections.append("- Account Number (weight: 3.0) - Critical identifier")
        sections.append("- Phone Number (weight: 1.0) - Standard field")
        sections.append("- Notes (weight: 0.5) - Optional supplementary info")
        sections.append("")
        sections.append(
            "The **Weighted Overall Score** aggregates individual field scores weighted by importance:"
        )
        sections.append("- **Formula**: `Σ(weight_i × score_i) / Σ(weight_i)`")
        sections.append("- **Section-level**: Weighted score for that specific section")
        sections.append("- **Document-level**: Average of all section weighted scores")
        sections.append("")
        sections.append("---")
        sections.append("")
        sections.append(
            "**Note**: Each attribute specifies its evaluation method via `x-aws-idp-evaluation-method` in the schema."
        )

        # Add Metrics Explanation at the very end
        if self.doc_split_metrics:
            sections.append("")
            sections.append("## 📖 Metrics Explanation")
            sections.append("")
            sections.append("### Page Level Accuracy")
            sections.append(
                "- Evaluates classification accuracy for **individual pages**"
            )
            sections.append(
                "- Each page index is checked: does its predicted `document_class` match expected?"
            )
            sections.append("- Does not consider page grouping into sections")
            sections.append("")
            sections.append("### Document Split Accuracy (Without Page Order)")
            sections.append(
                "- Evaluates whether pages are **correctly grouped into sections**"
            )
            sections.append(
                "- For each expected section, checks if predicted sections contain:"
            )
            sections.append("  - Same set of page indices (order doesn't matter)")
            sections.append("  - Same `document_class`")
            sections.append(
                "- Both conditions must be met for a section to be marked correct"
            )
            sections.append("")
            sections.append("### Document Split Accuracy (With Page Order)")
            sections.append("- Same as above but **page order must match exactly**")
            sections.append(
                "- The `page_indices` list must be identical (same pages, same order)"
            )
            sections.append("- Most strict evaluation metric")
            sections.append("")

        return "\n".join(sections)
