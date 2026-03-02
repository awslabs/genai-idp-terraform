export const validateStringConstraints = (attribute) => {
  const errors = [];

  if (attribute.minLength !== undefined && attribute.maxLength !== undefined) {
    if (attribute.minLength > attribute.maxLength) {
      errors.push({ field: 'minLength', message: 'minLength cannot be greater than maxLength' });
    }
  }

  if (attribute.minLength !== undefined && attribute.minLength < 0) {
    errors.push({ field: 'minLength', message: 'minLength must be non-negative' });
  }

  if (attribute.maxLength !== undefined && attribute.maxLength < 0) {
    errors.push({ field: 'maxLength', message: 'maxLength must be non-negative' });
  }

  return errors;
};

export const validateNumberConstraints = (attribute) => {
  const errors = [];

  if (attribute.minimum !== undefined && attribute.exclusiveMinimum !== undefined) {
    errors.push({ field: 'minimum', message: 'Cannot have both minimum and exclusiveMinimum' });
  }

  if (attribute.maximum !== undefined && attribute.exclusiveMaximum !== undefined) {
    errors.push({ field: 'maximum', message: 'Cannot have both maximum and exclusiveMaximum' });
  }

  const min = attribute.minimum ?? attribute.exclusiveMinimum;
  const max = attribute.maximum ?? attribute.exclusiveMaximum;

  if (min !== undefined && max !== undefined && min > max) {
    errors.push({ field: 'minimum', message: 'Minimum cannot be greater than maximum' });
  }

  if (attribute.multipleOf !== undefined && attribute.multipleOf <= 0) {
    errors.push({ field: 'multipleOf', message: 'multipleOf must be greater than 0' });
  }

  return errors;
};

export const validateArrayConstraints = (attribute) => {
  const errors = [];

  if (attribute.minItems !== undefined && attribute.maxItems !== undefined) {
    if (attribute.minItems > attribute.maxItems) {
      errors.push({ field: 'minItems', message: 'minItems cannot be greater than maxItems' });
    }
  }

  if (attribute.minContains !== undefined && attribute.maxContains !== undefined) {
    if (attribute.minContains > attribute.maxContains) {
      errors.push({ field: 'minContains', message: 'minContains cannot be greater than maxContains' });
    }
  }

  if (attribute.minItems !== undefined && attribute.minItems < 0) {
    errors.push({ field: 'minItems', message: 'minItems must be non-negative' });
  }

  if (attribute.maxItems !== undefined && attribute.maxItems < 0) {
    errors.push({ field: 'maxItems', message: 'maxItems must be non-negative' });
  }

  return errors;
};

export const validateObjectConstraints = (attribute) => {
  const errors = [];

  if (attribute.minProperties !== undefined && attribute.maxProperties !== undefined) {
    if (attribute.minProperties > attribute.maxProperties) {
      errors.push({ field: 'minProperties', message: 'minProperties cannot be greater than maxProperties' });
    }
  }

  if (attribute.minProperties !== undefined && attribute.minProperties < 0) {
    errors.push({ field: 'minProperties', message: 'minProperties must be non-negative' });
  }

  if (attribute.maxProperties !== undefined && attribute.maxProperties < 0) {
    errors.push({ field: 'maxProperties', message: 'maxProperties must be non-negative' });
  }

  return errors;
};

export const validateValueConstraints = (attribute) => {
  const errors = [];

  if (attribute.const !== undefined && attribute.enum !== undefined) {
    errors.push({ field: 'const', message: 'Cannot have both const and enum' });
  }

  return errors;
};

export const validateMetadata = (attribute) => {
  const errors = [];

  if (attribute.readOnly && attribute.writeOnly) {
    errors.push({ field: 'readOnly', message: 'Cannot be both readOnly and writeOnly' });
  }

  return errors;
};

export const validateAttribute = (attribute) => {
  if (!attribute || typeof attribute !== 'object') {
    return { valid: false, errors: [{ field: 'attribute', message: 'Attribute must be an object' }] };
  }

  const allErrors = [];

  if (!attribute.type && !attribute.$ref && !attribute.oneOf && !attribute.anyOf && !attribute.allOf) {
    allErrors.push({ field: 'type', message: 'Attribute must have a type, $ref, or composition keyword' });
  }

  if (attribute.type === 'string') {
    allErrors.push(...validateStringConstraints(attribute));
  }

  if (attribute.type === 'number' || attribute.type === 'integer') {
    allErrors.push(...validateNumberConstraints(attribute));
  }

  if (attribute.type === 'array') {
    allErrors.push(...validateArrayConstraints(attribute));
  }

  if (attribute.type === 'object') {
    allErrors.push(...validateObjectConstraints(attribute));
  }

  allErrors.push(...validateValueConstraints(attribute));
  allErrors.push(...validateMetadata(attribute));

  return {
    valid: allErrors.length === 0,
    errors: allErrors,
  };
};
