import React from 'react';
import PropTypes from 'prop-types';
import {
  Box,
  SpaceBetween,
  Header,
  FormField,
  Input,
  Select,
  Button,
  Container,
  ExpandableSection,
  Alert,
} from '@cloudscape-design/components';

const SchemaConditionalEditor = ({ selectedAttribute, availableClasses, onUpdate }) => {
  const hasConditional = selectedAttribute && selectedAttribute.if;

  const schemaTypeOptions = [
    { label: 'String', value: 'string' },
    { label: 'Number', value: 'number' },
    { label: 'Integer', value: 'integer' },
    { label: 'Boolean', value: 'boolean' },
    { label: 'Object', value: 'object' },
    { label: 'Array', value: 'array' },
    { label: 'Null', value: 'null' },
    ...(availableClasses || []).map((cls) => ({
      label: `Ref: ${cls.name}`,
      value: `#/$defs/${cls.name}`,
    })),
  ];

  const handleAddConditional = () => {
    const updates = {
      ...selectedAttribute,
      if: { type: 'string' },
      then: { type: 'string' },
    };
    onUpdate(updates);
  };

  const handleRemoveConditional = () => {
    const updates = { ...selectedAttribute };
    delete updates.if;
    delete updates.then;
    delete updates.else;
    onUpdate(updates);
  };

  const handleAddElse = () => {
    const updates = {
      ...selectedAttribute,
      else: { type: 'string' },
    };
    onUpdate(updates);
  };

  const handleRemoveElse = () => {
    const updates = { ...selectedAttribute };
    delete updates.else;
    onUpdate(updates);
  };

  const handleUpdateSchema = (key, field, value) => {
    const updates = { ...selectedAttribute };

    if (!updates[key]) {
      updates[key] = {};
    }

    if (field === 'type') {
      if (value.startsWith('#/$defs/')) {
        updates[key] = { $ref: value };
      } else {
        updates[key] = { type: value };
      }
    } else if (field === 'const') {
      try {
        updates[key].const = JSON.parse(value);
      } catch {
        updates[key].const = value;
      }
    } else {
      updates[key][field] = value;
    }

    onUpdate(updates);
  };

  const renderSchemaEditor = (key, label, description) => {
    const schema = selectedAttribute?.[key] || {};

    return (
      <Container>
        <SpaceBetween size="m">
          <Header variant="h4">{label}</Header>
          <Alert type="info">{description}</Alert>

          <FormField label="Schema Type">
            <Select
              selectedOption={
                schemaTypeOptions.find((opt) => schema.$ref === opt.value || schema.type === opt.value) || schemaTypeOptions[0]
              }
              onChange={({ detail }) => handleUpdateSchema(key, 'type', detail.selectedOption.value)}
              options={schemaTypeOptions}
            />
          </FormField>

          {key === 'if' && (
            <FormField label="Const Value (for if condition)" description="Exact value to match against">
              <Input
                value={schema.const !== undefined ? JSON.stringify(schema.const) : ''}
                onChange={({ detail }) => handleUpdateSchema(key, 'const', detail.value)}
                placeholder='e.g., "USA", 42'
              />
            </FormField>
          )}
        </SpaceBetween>
      </Container>
    );
  };

  if (!selectedAttribute) return null;

  return (
    <ExpandableSection headerText="Conditional Schema (if/then/else)" variant="container">
      <SpaceBetween size="m">
        <Alert type="info">
          Conditional schemas allow validation to change based on the value of the data. Use this for scenarios like: different validation
          rules per country, required fields based on a status, or format validation based on type.
        </Alert>

        {!hasConditional ? (
          <Container>
            <SpaceBetween size="m">
              <p>Add conditional validation to this attribute</p>
              <Button onClick={handleAddConditional} variant="primary">
                Add if/then Condition
              </Button>
            </SpaceBetween>
          </Container>
        ) : (
          <SpaceBetween size="m">
            <Box float="right">
              <Button onClick={handleRemoveConditional} variant="normal">
                Remove Conditional
              </Button>
            </Box>

            {renderSchemaEditor('if', 'If (Condition)', 'When the data matches this schema...')}
            {renderSchemaEditor('then', 'Then (When true)', 'Apply this schema if the condition is true')}

            {!selectedAttribute.else ? (
              <Button onClick={handleAddElse} variant="normal">
                Add Else Branch
              </Button>
            ) : (
              <>
                {renderSchemaEditor('else', 'Else (When false)', 'Apply this schema if the condition is false')}
                <Button onClick={handleRemoveElse} variant="link">
                  Remove Else Branch
                </Button>
              </>
            )}
          </SpaceBetween>
        )}
      </SpaceBetween>
    </ExpandableSection>
  );
};

SchemaConditionalEditor.propTypes = {
  selectedAttribute: PropTypes.shape({}),
  availableClasses: PropTypes.arrayOf(
    PropTypes.shape({
      name: PropTypes.string,
    }),
  ),
  onUpdate: PropTypes.func.isRequired,
};

SchemaConditionalEditor.defaultProps = {
  selectedAttribute: null,
  availableClasses: [],
};

export default SchemaConditionalEditor;
