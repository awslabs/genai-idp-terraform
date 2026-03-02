import React from 'react';
import PropTypes from 'prop-types';
import { Header, FormField, Input, Checkbox, ExpandableSection, SpaceBetween } from '@cloudscape-design/components';
import ContainsSchemaBuilder from './ContainsSchemaBuilder';

const ArrayConstraints = ({ attribute, onUpdate, availableClasses }) => {
  if (attribute.type !== 'array') return null;

  const handleContainsSchemaChange = (schema) => {
    if (!schema || Object.keys(schema).length === 0) {
      const updates = { ...attribute };
      delete updates.contains;
      delete updates.minContains;
      delete updates.maxContains;
      onUpdate(updates);
      return;
    }

    onUpdate({ contains: schema });
  };

  return (
    <>
      <Header variant="h4">Array Constraints</Header>

      <FormField label="Min Items" description="Minimum number of items expected in the array. Use 1 to require at least one item.">
        <Input
          type="number"
          value={attribute.minItems?.toString() || ''}
          onChange={({ detail }) => onUpdate({ minItems: detail.value ? parseInt(detail.value, 10) : undefined })}
          placeholder="e.g., 1 for at least one item"
        />
      </FormField>

      <FormField label="Max Items" description="Maximum number of items allowed in the array. Leave empty for unlimited.">
        <Input
          type="number"
          value={attribute.maxItems?.toString() || ''}
          onChange={({ detail }) => onUpdate({ maxItems: detail.value ? parseInt(detail.value, 10) : undefined })}
          placeholder="e.g., 10"
        />
      </FormField>

      <Checkbox checked={attribute.uniqueItems || false} onChange={({ detail }) => onUpdate({ uniqueItems: detail.checked || undefined })}>
        Unique Items (all array elements must be unique, no duplicates allowed)
      </Checkbox>

      <ExpandableSection headerText="Advanced: Pattern Matching (Contains)" variant="footer">
        <SpaceBetween size="m">
          <ContainsSchemaBuilder
            containsSchema={attribute.contains}
            onChange={handleContainsSchemaChange}
            availableClasses={availableClasses}
          />

          {attribute.contains && (
            <>
              <FormField
                label="Min Contains"
                description="Minimum number of items that must match the contains schema. Leave empty for at least 1."
              >
                <Input
                  type="number"
                  value={attribute.minContains?.toString() || ''}
                  onChange={({ detail }) =>
                    onUpdate({
                      minContains: detail.value ? parseInt(detail.value, 10) : undefined,
                    })
                  }
                  placeholder="e.g., 2"
                />
              </FormField>

              <FormField
                label="Max Contains"
                description="Maximum number of items that can match the contains schema. Leave empty for unlimited."
              >
                <Input
                  type="number"
                  value={attribute.maxContains?.toString() || ''}
                  onChange={({ detail }) =>
                    onUpdate({
                      maxContains: detail.value ? parseInt(detail.value, 10) : undefined,
                    })
                  }
                  placeholder="e.g., 5"
                />
              </FormField>
            </>
          )}
        </SpaceBetween>
      </ExpandableSection>
    </>
  );
};

ArrayConstraints.propTypes = {
  attribute: PropTypes.shape({
    type: PropTypes.string,
    minItems: PropTypes.number,
    maxItems: PropTypes.number,
    uniqueItems: PropTypes.bool,
    contains: PropTypes.shape({}),
    minContains: PropTypes.number,
    maxContains: PropTypes.number,
  }).isRequired,
  onUpdate: PropTypes.func.isRequired,
  availableClasses: PropTypes.arrayOf(
    PropTypes.shape({
      name: PropTypes.string,
      id: PropTypes.string,
    }),
  ),
};

ArrayConstraints.defaultProps = {
  availableClasses: [],
};

export default ArrayConstraints;
