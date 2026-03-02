import React, { useState, useRef } from 'react';
import PropTypes from 'prop-types';
import { Box, SpaceBetween, Header, FormField, Select, Button, Container, ExpandableSection, Alert } from '@cloudscape-design/components';

const SchemaCompositionEditor = ({ selectedAttribute = null, availableClasses = [], onUpdate }) => {
  const [compositionType, setCompositionType] = useState('');
  const schemaIdCounterRef = useRef(0);

  const compositionOptions = [
    { label: 'None', value: '', description: 'No composition' },
    { label: 'One Of (Exclusive Choice)', value: 'oneOf', description: 'Must match exactly one schema' },
    { label: 'Any Of (Inclusive Choice)', value: 'anyOf', description: 'Must match at least one schema' },
    { label: 'All Of (Combination)', value: 'allOf', description: 'Must match all schemas' },
    { label: 'Not (Negation)', value: 'not', description: 'Must not match the schema' },
  ];

  const hasComposition =
    selectedAttribute && (selectedAttribute.oneOf || selectedAttribute.anyOf || selectedAttribute.allOf || selectedAttribute.not);

  let currentComposition = '';
  if (hasComposition) {
    if (selectedAttribute.oneOf) {
      currentComposition = 'oneOf';
    } else if (selectedAttribute.anyOf) {
      currentComposition = 'anyOf';
    } else if (selectedAttribute.allOf) {
      currentComposition = 'allOf';
    } else if (selectedAttribute.not) {
      currentComposition = 'not';
    }
  }

  const handleAddComposition = () => {
    if (!compositionType) return;

    const updates = { ...selectedAttribute };

    if (compositionType === 'not') {
      const schemaId = schemaIdCounterRef.current;
      schemaIdCounterRef.current += 1;
      updates.not = { type: 'string', schemaId };
    } else {
      const schemaId1 = schemaIdCounterRef.current;
      schemaIdCounterRef.current += 1;
      const schemaId2 = schemaIdCounterRef.current;
      schemaIdCounterRef.current += 1;
      updates[compositionType] = [
        { type: 'string', schemaId: schemaId1 },
        { type: 'number', schemaId: schemaId2 },
      ];
    }

    onUpdate(updates);
    setCompositionType('');
  };

  const handleRemoveComposition = () => {
    const updates = { ...selectedAttribute };
    delete updates.oneOf;
    delete updates.anyOf;
    delete updates.allOf;
    delete updates.not;
    onUpdate(updates);
  };

  const handleAddSchema = () => {
    if (!currentComposition || currentComposition === 'not') return;

    const updates = { ...selectedAttribute };
    const schemaId = schemaIdCounterRef.current;
    schemaIdCounterRef.current += 1;
    updates[currentComposition] = [...(updates[currentComposition] || []), { type: 'string', schemaId }];
    onUpdate(updates);
  };

  const handleRemoveSchema = (index) => {
    if (!currentComposition || currentComposition === 'not') return;

    const updates = { ...selectedAttribute };
    const schemas = [...(updates[currentComposition] || [])];
    schemas.splice(index, 1);

    if (schemas.length === 0) {
      delete updates[currentComposition];
    } else {
      updates[currentComposition] = schemas;
    }

    onUpdate(updates);
  };

  const handleUpdateSchema = (index, newType) => {
    if (!currentComposition || currentComposition === 'not') return;

    const updates = { ...selectedAttribute };
    const schemas = [...(updates[currentComposition] || [])];
    const existingSchemaId = schemas[index].schemaId;

    if (newType.startsWith('#/$defs/')) {
      schemas[index] = { $ref: newType, schemaId: existingSchemaId };
    } else {
      schemas[index] = { type: newType, schemaId: existingSchemaId };
    }

    updates[currentComposition] = schemas;
    onUpdate(updates);
  };

  const handleUpdateNotSchema = (newType) => {
    const updates = { ...selectedAttribute };

    if (newType.startsWith('#/$defs/')) {
      updates.not = { $ref: newType };
    } else {
      updates.not = { type: newType };
    }

    onUpdate(updates);
  };

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

  if (!selectedAttribute) return null;

  return (
    <ExpandableSection headerText="Schema Composition (Advanced)" variant="container">
      <SpaceBetween size="m">
        <Alert type="info">
          Schema composition allows you to combine multiple schemas using logical operators. This enables complex validation scenarios like
          discriminated unions, polymorphic types, and conditional logic.
        </Alert>

        {!hasComposition ? (
          <Container>
            <SpaceBetween size="m">
              <FormField label="Add Composition" description="Choose how to combine multiple schemas">
                <Select
                  selectedOption={compositionOptions.find((opt) => opt.value === compositionType) || compositionOptions[0]}
                  onChange={({ detail }) => setCompositionType(detail.selectedOption.value)}
                  options={compositionOptions}
                  placeholder="Select composition type"
                />
              </FormField>
              <Button onClick={handleAddComposition} disabled={!compositionType}>
                Add Composition
              </Button>
            </SpaceBetween>
          </Container>
        ) : (
          <Container>
            <SpaceBetween size="m">
              <Header
                variant="h3"
                actions={
                  <Button onClick={handleRemoveComposition} variant="normal">
                    Remove Composition
                  </Button>
                }
              >
                {compositionOptions.find((opt) => opt.value === currentComposition)?.label || 'Composition'}
              </Header>

              {currentComposition === 'not' ? (
                <FormField label="Schema to Negate" description="Value must NOT match this schema">
                  <Select
                    selectedOption={
                      schemaTypeOptions.find(
                        (opt) => selectedAttribute.not?.$ref === opt.value || selectedAttribute.not?.type === opt.value,
                      ) || schemaTypeOptions[0]
                    }
                    onChange={({ detail }) => handleUpdateNotSchema(detail.selectedOption.value)}
                    options={schemaTypeOptions}
                  />
                </FormField>
              ) : (
                <>
                  {(selectedAttribute[currentComposition] || []).map((schema, idx) => (
                    <Box
                      key={schema.schemaId || `${currentComposition}-fallback-${idx}`}
                      padding="s"
                      style={{ border: '1px solid #ddd', borderRadius: '4px' }}
                    >
                      <SpaceBetween size="s">
                        <Header variant="h4" actions={<Button variant="icon" iconName="close" onClick={() => handleRemoveSchema(idx)} />}>
                          Schema {idx + 1}
                        </Header>
                        <FormField label="Type">
                          <Select
                            selectedOption={
                              schemaTypeOptions.find((opt) => schema.$ref === opt.value || schema.type === opt.value) ||
                              schemaTypeOptions[0]
                            }
                            onChange={({ detail }) => handleUpdateSchema(idx, detail.selectedOption.value)}
                            options={schemaTypeOptions}
                          />
                        </FormField>
                      </SpaceBetween>
                    </Box>
                  ))}
                  <Button onClick={handleAddSchema} variant="normal">
                    Add Schema to {currentComposition}
                  </Button>
                </>
              )}
            </SpaceBetween>
          </Container>
        )}
      </SpaceBetween>
    </ExpandableSection>
  );
};

SchemaCompositionEditor.propTypes = {
  selectedAttribute: PropTypes.shape({}),
  availableClasses: PropTypes.arrayOf(
    PropTypes.shape({
      name: PropTypes.string,
    }),
  ),
  onUpdate: PropTypes.func.isRequired,
};

export default SchemaCompositionEditor;
