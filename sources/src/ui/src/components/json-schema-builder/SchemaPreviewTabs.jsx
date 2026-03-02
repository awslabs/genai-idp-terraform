import React, { useState, useMemo } from 'react';
import PropTypes from 'prop-types';
import { Box, Tabs, SpaceBetween, Alert, Container, Header } from '@cloudscape-design/components';
import Editor from '@monaco-editor/react';
import { X_AWS_IDP_DOCUMENT_TYPE } from '../../constants/schemaConstants';

const getSchemaStats = (schema) => {
  if (!schema) return {};

  const props = schema.attributes?.properties || {};
  const stats = {
    totalAttributes: Object.keys(props).length,
    requiredAttributes: (schema.attributes?.required || []).length,
    stringAttributes: 0,
    numberAttributes: 0,
    booleanAttributes: 0,
    objectAttributes: 0,
    arrayAttributes: 0,
    withConstraints: 0,
    withComposition: 0,
    withConditional: 0,
  };

  Object.values(props).forEach((attr) => {
    if (attr.type === 'string') {
      stats.stringAttributes += 1;
    } else if (attr.type === 'number' || attr.type === 'integer') {
      stats.numberAttributes += 1;
    } else if (attr.type === 'boolean') {
      stats.booleanAttributes += 1;
    } else if (attr.type === 'object') {
      stats.objectAttributes += 1;
    } else if (attr.type === 'array') {
      stats.arrayAttributes += 1;
    }

    if (attr.pattern || attr.format || attr.minLength || attr.maxLength || attr.minimum || attr.maximum || attr.enum || attr.const) {
      stats.withConstraints += 1;
    }

    if (attr.oneOf || attr.anyOf || attr.allOf || attr.not) {
      stats.withComposition += 1;
    }

    if (attr.if) {
      stats.withConditional += 1;
    }
  });

  return stats;
};

const SchemaStatsContent = ({ stats }) => (
  <Box>
    <SpaceBetween size="m">
      <Container header={<Header variant="h3">Attribute Overview</Header>}>
        <SpaceBetween size="s">
          <Box>
            Total Attributes: <strong>{stats.totalAttributes}</strong>
          </Box>
          <Box>
            Required Attributes: <strong>{stats.requiredAttributes}</strong>
          </Box>
          <Box>
            Optional Attributes: <strong>{stats.totalAttributes - stats.requiredAttributes}</strong>
          </Box>
        </SpaceBetween>
      </Container>

      <Container header={<Header variant="h3">Type Distribution</Header>}>
        <SpaceBetween size="s">
          <Box>
            String: <strong>{stats.stringAttributes}</strong>
          </Box>
          <Box>
            Number/Integer: <strong>{stats.numberAttributes}</strong>
          </Box>
          <Box>
            Boolean: <strong>{stats.booleanAttributes}</strong>
          </Box>
          <Box>
            Object: <strong>{stats.objectAttributes}</strong>
          </Box>
          <Box>
            Array: <strong>{stats.arrayAttributes}</strong>
          </Box>
        </SpaceBetween>
      </Container>

      <Container header={<Header variant="h3">Advanced Features</Header>}>
        <SpaceBetween size="s">
          <Box>
            Attributes with Constraints: <strong>{stats.withConstraints}</strong>
          </Box>
          <Box>
            Attributes with Composition (oneOf/anyOf/allOf): <strong>{stats.withComposition}</strong>
          </Box>
          <Box>
            Attributes with Conditionals (if/then/else): <strong>{stats.withConditional}</strong>
          </Box>
        </SpaceBetween>
      </Container>
    </SpaceBetween>
  </Box>
);

SchemaStatsContent.propTypes = {
  stats: PropTypes.shape({
    totalAttributes: PropTypes.number,
    requiredAttributes: PropTypes.number,
    stringAttributes: PropTypes.number,
    numberAttributes: PropTypes.number,
    booleanAttributes: PropTypes.number,
    objectAttributes: PropTypes.number,
    arrayAttributes: PropTypes.number,
    withConstraints: PropTypes.number,
    withComposition: PropTypes.number,
    withConditional: PropTypes.number,
  }).isRequired,
};

const SchemaPreviewTabs = ({ classes, selectedClassId, exportedSchemas }) => {
  const [activeTabId, setActiveTabId] = useState('schema-0');

  // Memoize selected class with shallow comparison
  const selectedClass = useMemo(() => {
    return classes.find((cls) => cls.id === selectedClassId);
  }, [classes, selectedClassId]);

  // Determine if we have multiple schemas
  const schemas = useMemo(() => {
    if (!exportedSchemas) return [];
    const schemaArray = Array.isArray(exportedSchemas) ? exportedSchemas : [exportedSchemas];
    return schemaArray;
  }, [exportedSchemas]);

  // Generate tabs for each document type schema
  const schemaTabs = useMemo(() => {
    return schemas.map((schema, index) => ({
      id: `schema-${index}`,
      label: schemas.length > 1 ? `${schema[X_AWS_IDP_DOCUMENT_TYPE] || schema.$id || `Schema ${index + 1}`}` : 'JSON Schema',
      content: (
        <SpaceBetween size="m">
          <Alert type="info">
            {schemas.length > 1
              ? `JSON Schema for document type: ${schema[X_AWS_IDP_DOCUMENT_TYPE] || schema.$id}`
              : 'JSON Schema draft 2020-12 representation'}
            <br />
            {schema.$defs && Object.keys(schema.$defs).length > 0 && (
              <>This schema includes {Object.keys(schema.$defs).length} referenced class(es) in $defs</>
            )}
          </Alert>
          <Editor
            height="calc(100vh - 400px)"
            defaultLanguage="json"
            value={JSON.stringify(schema, null, 2)}
            options={{
              readOnly: true,
              minimap: { enabled: false },
              lineNumbers: 'on',
              scrollBeyondLastLine: false,
              wordWrap: 'on',
            }}
            theme="vs"
          />
        </SpaceBetween>
      ),
    }));
  }, [schemas]);

  if (schemas.length === 0) {
    return (
      <Box textAlign="center" padding="xxl">
        <Alert type="info">Configure document types and classes to preview schemas</Alert>
      </Box>
    );
  }

  // Combine all tabs
  const allTabs = [
    ...schemaTabs,
    ...(selectedClass
      ? [
          {
            id: 'stats',
            label: 'Statistics',
            content: (
              <SpaceBetween size="m">
                <Alert type="info">Schema complexity and feature usage statistics (selected class: {selectedClass.name})</Alert>
                <SchemaStatsContent stats={getSchemaStats(selectedClass)} />
              </SpaceBetween>
            ),
          },
        ]
      : []),
  ];

  return (
    <Box>
      <Tabs activeTabId={activeTabId} onChange={({ detail }) => setActiveTabId(detail.activeTabId)} tabs={allTabs} />
    </Box>
  );
};

// Memoize the component to prevent re-renders when props haven't changed
export default React.memo(SchemaPreviewTabs);

SchemaPreviewTabs.propTypes = {
  classes: PropTypes.arrayOf(PropTypes.shape({})).isRequired,
  selectedClassId: PropTypes.string,
  exportedSchemas: PropTypes.oneOfType([PropTypes.shape({}), PropTypes.arrayOf(PropTypes.shape({}))]),
};

SchemaPreviewTabs.defaultProps = {
  selectedClassId: null,
  exportedSchemas: null,
};
