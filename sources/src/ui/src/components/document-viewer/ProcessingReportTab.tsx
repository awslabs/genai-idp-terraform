// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

import React from 'react';
import {
  Container,
  Header,
  SpaceBetween,
  Box,
  Alert,
  ColumnLayout,
  StatusIndicator,
  ExpandableSection,
} from '@cloudscape-design/components';

interface Violation {
  field: string;
  message: string;
  possible_cause: string;
}

interface SchemaAnalysis {
  large_array_fields?: string[];
  max_min_items?: number;
  recommendation_strength?: string;
  recommendation_reason?: string;
}

interface OcrAnalysis {
  tables_detected?: number;
  estimated_row_count?: number;
  recommendation_strength?: string;
  recommendation_reason?: string;
}

interface ToolUsageDecision {
  expected?: boolean;
  actual?: boolean;
  mismatch?: boolean;
  explanation?: string;
}

interface CompletenessCheck {
  schema_constraints_met?: boolean;
  violations?: Violation[];
  summary?: string;
}

interface TableParsingStats {
  tables_parsed?: number;
  rows_parsed?: number;
  parse_success_rate?: number;
  avg_confidence?: number;
  warnings?: string[];
}

interface ProcessingMetadata {
  extraction_method?: string;
  extraction_time_seconds?: number;
  parsing_succeeded?: boolean;
  schema_analysis?: SchemaAnalysis;
  ocr_analysis?: OcrAnalysis;
  tool_usage_decision?: ToolUsageDecision;
  completeness_check?: CompletenessCheck;
  table_parsing_tool_used?: boolean;
  table_parsing_stats?: TableParsingStats;
}

interface ProcessingReportTabProps {
  metadata?: ProcessingMetadata;
  processingReport?: string;
}

const ProcessingReportTab: React.FC<ProcessingReportTabProps> = ({ metadata, processingReport }) => {
  if (!metadata || !processingReport) {
    return (
      <Box padding="l" textAlign="center" color="text-status-inactive">
        Processing report not available
      </Box>
    );
  }

  const extractionMethod = metadata.extraction_method || 'unknown';
  const toolUsed = metadata.table_parsing_tool_used;
  const toolDecision = metadata.tool_usage_decision || {};
  const completenessCheck = metadata.completeness_check || {};
  const hasIssues = toolDecision.mismatch || !completenessCheck.schema_constraints_met;

  return (
    <SpaceBetween size="l">
      {/* Alert banner for issues */}
      {hasIssues && (
        <Alert type="warning" header="Extraction Issues Detected">
          <SpaceBetween size="s">
            {toolDecision.mismatch && (
              <Box>
                <strong>Tool Usage Mismatch:</strong> {toolDecision.explanation}
              </Box>
            )}
            {!completenessCheck.schema_constraints_met && (
              <Box>
                <strong>Completeness Issue:</strong> {completenessCheck.summary}
              </Box>
            )}
          </SpaceBetween>
        </Alert>
      )}

      {/* Overview */}
      <Container header={<Header variant="h2">Extraction Overview</Header>}>
        <ColumnLayout columns={3} variant="text-grid">
          <div>
            <Box variant="awsui-key-label">Method</Box>
            <Box>
              <StatusIndicator type="success">{extractionMethod.toUpperCase()}</StatusIndicator>
            </Box>
          </div>
          <div>
            <Box variant="awsui-key-label">Processing Time</Box>
            <Box>{metadata.extraction_time_seconds?.toFixed(1) || 'N/A'}s</Box>
          </div>
          <div>
            <Box variant="awsui-key-label">Status</Box>
            <Box>
              <StatusIndicator type={metadata.parsing_succeeded ? 'success' : 'error'}>
                {metadata.parsing_succeeded ? 'SUCCESS' : 'FAILED'}
              </StatusIndicator>
            </Box>
          </div>
        </ColumnLayout>
      </Container>

      {/* Schema Analysis */}
      {metadata.schema_analysis && (
        <Container header={<Header variant="h3">Schema Analysis</Header>}>
          <ColumnLayout columns={2} variant="text-grid">
            <div>
              <Box variant="awsui-key-label">Large Array Fields</Box>
              <Box>
                {metadata.schema_analysis.large_array_fields?.length || 0}
                {metadata.schema_analysis.large_array_fields &&
                  metadata.schema_analysis.large_array_fields.length > 0 &&
                  ` (${metadata.schema_analysis.large_array_fields.join(', ')})`}
              </Box>
            </div>
            <div>
              <Box variant="awsui-key-label">Max minItems Constraint</Box>
              <Box>{metadata.schema_analysis.max_min_items || 0}</Box>
            </div>
            <div>
              <Box variant="awsui-key-label">Tool Recommendation</Box>
              <Box>
                <StatusIndicator type={metadata.schema_analysis.recommendation_strength === 'MANDATORY' ? 'warning' : 'info'}>
                  {metadata.schema_analysis.recommendation_strength || 'N/A'}
                </StatusIndicator>
              </Box>
            </div>
            <div>
              <Box variant="awsui-key-label">Reason</Box>
              <Box fontSize="body-s">{metadata.schema_analysis.recommendation_reason || 'N/A'}</Box>
            </div>
          </ColumnLayout>
        </Container>
      )}

      {/* OCR Analysis */}
      {metadata.ocr_analysis && (
        <Container header={<Header variant="h3">OCR Table Detection</Header>}>
          <ColumnLayout columns={2} variant="text-grid">
            <div>
              <Box variant="awsui-key-label">Tables Detected</Box>
              <Box>{metadata.ocr_analysis.tables_detected || 0}</Box>
            </div>
            <div>
              <Box variant="awsui-key-label">Estimated Rows</Box>
              <Box>{metadata.ocr_analysis.estimated_row_count || 0}</Box>
            </div>
            <div>
              <Box variant="awsui-key-label">Tool Recommendation</Box>
              <Box>
                <StatusIndicator type={metadata.ocr_analysis.recommendation_strength === 'MANDATORY' ? 'warning' : 'info'}>
                  {metadata.ocr_analysis.recommendation_strength || 'N/A'}
                </StatusIndicator>
              </Box>
            </div>
            <div>
              <Box variant="awsui-key-label">Reason</Box>
              <Box fontSize="body-s">{metadata.ocr_analysis.recommendation_reason || 'N/A'}</Box>
            </div>
          </ColumnLayout>
        </Container>
      )}

      {/* Tool Usage Decision */}
      {extractionMethod === 'agentic' && toolDecision.expected !== undefined && (
        <Container
          header={
            <Header variant="h3" description="Whether the table parsing tool was used as expected">
              Table Parsing Tool Decision
            </Header>
          }
        >
          <ColumnLayout columns={3} variant="text-grid">
            <div>
              <Box variant="awsui-key-label">Expected</Box>
              <Box>
                <StatusIndicator type={toolDecision.expected ? 'success' : 'info'}>{toolDecision.expected ? 'YES' : 'NO'}</StatusIndicator>
              </Box>
            </div>
            <div>
              <Box variant="awsui-key-label">Actual</Box>
              <Box>
                <StatusIndicator type={toolUsed ? 'success' : 'warning'}>{toolUsed ? 'USED' : 'NOT USED'}</StatusIndicator>
              </Box>
            </div>
            <div>
              <Box variant="awsui-key-label">Match</Box>
              <Box>
                <StatusIndicator type={toolDecision.mismatch ? 'error' : 'success'}>
                  {toolDecision.mismatch ? 'MISMATCH' : 'MATCH'}
                </StatusIndicator>
              </Box>
            </div>
          </ColumnLayout>
          <Box padding={{ top: 's' }} fontSize="body-s">
            <strong>Explanation:</strong> {toolDecision.explanation || 'N/A'}
          </Box>
        </Container>
      )}

      {/* Completeness Check */}
      {completenessCheck.violations && completenessCheck.violations.length > 0 && (
        <Container header={<Header variant="h3">Completeness Validation</Header>}>
          <Alert type="error" header={completenessCheck.summary}>
            <SpaceBetween size="s">
              {(completenessCheck.violations as Violation[]).map((v) => (
                <Box key={`violation-${v.field}`}>
                  <strong>Field &quot;{v.field}&quot;:</strong> {v.message}
                  <br />
                  <Box fontSize="body-s" color="text-status-inactive">
                    Possible cause: {v.possible_cause}
                  </Box>
                </Box>
              ))}
            </SpaceBetween>
          </Alert>
        </Container>
      )}

      {/* Completeness Check - Success */}
      {completenessCheck.schema_constraints_met && (
        <Container header={<Header variant="h3">Completeness Validation</Header>}>
          <Alert type="success" header={completenessCheck.summary}>
            All required data was extracted successfully.
          </Alert>
        </Container>
      )}

      {/* Table Parsing Stats */}
      {toolUsed && metadata.table_parsing_stats && (
        <Container header={<Header variant="h3">Table Parsing Results</Header>}>
          <ColumnLayout columns={2} variant="text-grid">
            <div>
              <Box variant="awsui-key-label">Tables Parsed</Box>
              <Box>{metadata.table_parsing_stats.tables_parsed || 0}</Box>
            </div>
            <div>
              <Box variant="awsui-key-label">Total Rows Extracted</Box>
              <Box>{metadata.table_parsing_stats.rows_parsed || 0}</Box>
            </div>
            <div>
              <Box variant="awsui-key-label">Parse Success Rate</Box>
              <Box>{((metadata.table_parsing_stats.parse_success_rate || 0) * 100).toFixed(1)}%</Box>
            </div>
            <div>
              <Box variant="awsui-key-label">Avg OCR Confidence</Box>
              <Box>{(metadata.table_parsing_stats.avg_confidence || 0).toFixed(1)}%</Box>
            </div>
          </ColumnLayout>

          {metadata.table_parsing_stats.warnings && metadata.table_parsing_stats.warnings.length > 0 && (
            <Box padding={{ top: 's' }}>
              <ExpandableSection headerText="Warnings">
                <SpaceBetween size="xs">
                  {(metadata.table_parsing_stats.warnings as string[]).map((w) => (
                    <Box key={`warning-${w}`} fontSize="body-s">
                      • {w}
                    </Box>
                  ))}
                </SpaceBetween>
              </ExpandableSection>
            </Box>
          )}
        </Container>
      )}

      {/* Full Text Report */}
      <ExpandableSection headerText="Full Processing Report (Text)" defaultExpanded={false}>
        <Box padding="s" variant="code">
          <pre style={{ margin: 0, whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>{processingReport}</pre>
        </Box>
      </ExpandableSection>
    </SpaceBetween>
  );
};

export default ProcessingReportTab;
