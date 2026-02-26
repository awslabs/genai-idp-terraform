import React from 'react';
import PropTypes from 'prop-types';
import { Header, FormField, Input } from '@cloudscape-design/components';

const NumberConstraints = ({ attribute, onUpdate }) => {
  if (attribute.type !== 'number' && attribute.type !== 'integer') return null;

  return (
    <>
      <Header variant="h4">Number Constraints</Header>

      <FormField label="Minimum" description="Minimum value (inclusive)">
        <Input
          type="number"
          step="any"
          value={attribute.minimum?.toString() || ''}
          onChange={({ detail }) => {
            const updates = { minimum: detail.value ? parseFloat(detail.value) : undefined };
            if (detail.value && attribute.exclusiveMinimum !== undefined) {
              updates.exclusiveMinimum = undefined;
            }
            onUpdate(updates);
          }}
          disabled={attribute.exclusiveMinimum !== undefined}
        />
      </FormField>

      <FormField label="Exclusive Minimum" description="Minimum value (exclusive, value must be greater than this)">
        <Input
          type="number"
          step="any"
          value={attribute.exclusiveMinimum?.toString() || ''}
          onChange={({ detail }) => {
            const updates = { exclusiveMinimum: detail.value ? parseFloat(detail.value) : undefined };
            if (detail.value && attribute.minimum !== undefined) {
              updates.minimum = undefined;
            }
            onUpdate(updates);
          }}
          disabled={attribute.minimum !== undefined}
        />
      </FormField>

      <FormField label="Maximum" description="Maximum value (inclusive)">
        <Input
          type="number"
          step="any"
          value={attribute.maximum?.toString() || ''}
          onChange={({ detail }) => {
            const updates = { maximum: detail.value ? parseFloat(detail.value) : undefined };
            if (detail.value && attribute.exclusiveMaximum !== undefined) {
              updates.exclusiveMaximum = undefined;
            }
            onUpdate(updates);
          }}
          disabled={attribute.exclusiveMaximum !== undefined}
        />
      </FormField>

      <FormField label="Exclusive Maximum" description="Maximum value (exclusive, value must be less than this)">
        <Input
          type="number"
          step="any"
          value={attribute.exclusiveMaximum?.toString() || ''}
          onChange={({ detail }) => {
            const updates = { exclusiveMaximum: detail.value ? parseFloat(detail.value) : undefined };
            if (detail.value && attribute.maximum !== undefined) {
              updates.maximum = undefined;
            }
            onUpdate(updates);
          }}
          disabled={attribute.maximum !== undefined}
        />
      </FormField>

      <FormField label="Multiple Of" description="Value must be a multiple of this number">
        <Input
          type="number"
          step="any"
          value={attribute.multipleOf?.toString() || ''}
          onChange={({ detail }) => onUpdate({ multipleOf: detail.value ? parseFloat(detail.value) : undefined })}
          placeholder="e.g., 0.01 for currency, 5 for intervals"
        />
      </FormField>
    </>
  );
};

NumberConstraints.propTypes = {
  attribute: PropTypes.shape({
    type: PropTypes.string,
    minimum: PropTypes.number,
    maximum: PropTypes.number,
    exclusiveMinimum: PropTypes.number,
    exclusiveMaximum: PropTypes.number,
    multipleOf: PropTypes.number,
  }).isRequired,
  onUpdate: PropTypes.func.isRequired,
};

export default NumberConstraints;
