import React from 'react';
import PropTypes from 'prop-types';
import { Header, FormField, Input, Checkbox } from '@cloudscape-design/components';

const ObjectConstraints = ({ attribute, onUpdate }) => {
  if (attribute.type !== 'object' || attribute.$ref) return null;

  return (
    <>
      <Header variant="h4">Object Constraints</Header>

      <FormField label="Min Properties" description="Minimum number of properties">
        <Input
          type="number"
          value={attribute.minProperties?.toString() || ''}
          onChange={({ detail }) => onUpdate({ minProperties: detail.value ? parseInt(detail.value, 10) : undefined })}
        />
      </FormField>

      <FormField label="Max Properties" description="Maximum number of properties">
        <Input
          type="number"
          value={attribute.maxProperties?.toString() || ''}
          onChange={({ detail }) => onUpdate({ maxProperties: detail.value ? parseInt(detail.value, 10) : undefined })}
        />
      </FormField>

      <Checkbox
        checked={attribute.additionalProperties === false}
        onChange={({ detail }) => onUpdate({ additionalProperties: detail.checked ? false : undefined })}
      >
        Disallow Additional Properties
      </Checkbox>
    </>
  );
};

ObjectConstraints.propTypes = {
  attribute: PropTypes.shape({
    type: PropTypes.string,
    $ref: PropTypes.string,
    minProperties: PropTypes.number,
    maxProperties: PropTypes.number,
    additionalProperties: PropTypes.oneOfType([PropTypes.bool, PropTypes.object]),
  }).isRequired,
  onUpdate: PropTypes.func.isRequired,
};

export default ObjectConstraints;
