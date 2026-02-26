import { useState, useCallback, useMemo } from 'react';
import Ajv from 'ajv';
import addFormats from 'ajv-formats';

const EXTRACTION_JSON_SCHEMA = {
  type: 'object',
  properties: {
    name: {
      type: 'string',
      description: 'The name of the document class',
    },
    description: {
      type: 'string',
      description: 'Description of the document class',
    },
    attributes: {
      type: 'object',
      description: 'The extraction schema defining attributes to extract',
      properties: {},
      additionalProperties: true,
    },
  },
  required: ['name', 'attributes'],
  additionalProperties: true,
};

export const useSchemaValidation = () => {
  const [validationErrors, setValidationErrors] = useState([]);

  const ajv = useMemo(() => {
    const instance = new Ajv({
      allErrors: true, // nosemgrep: javascript.ajv.security.audit.ajv-allerrors-true.ajv-allerrors-true - allErrors required for comprehensive validation feedback for user created schemas in UI
      strict: false,
      validateFormats: true,
      discriminator: true,
      allowUnionTypes: true,
    });
    addFormats(instance);
    return instance;
  }, []);

  const validateSchema = useCallback(
    (schema) => {
      try {
        const validate = ajv.compile(EXTRACTION_JSON_SCHEMA);
        const valid = validate(schema);

        if (!valid && validate.errors) {
          const errors = validate.errors.map((error) => ({
            path: error.instancePath || '/',
            message: error.message || 'Validation error',
            keyword: error.keyword,
          }));
          return { valid: false, errors };
        }

        return { valid: true, errors: [] };
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Unknown validation error';
        const errors = [{ path: '/', message: errorMessage }];
        return { valid: false, errors };
      }
    },
    [ajv],
  );

  const validateAttribute = useCallback((attribute) => {
    const errors = [];

    if (!attribute || typeof attribute !== 'object') {
      return { valid: false, errors: [{ path: '/', message: 'Attribute must be an object' }] };
    }

    if (!attribute.type && !attribute.$ref && !attribute.oneOf && !attribute.anyOf && !attribute.allOf) {
      errors.push({ path: '/', message: 'Attribute must have a type, $ref, or composition keyword' });
    }

    if (attribute.type === 'string') {
      if (attribute.minLength !== undefined && attribute.maxLength !== undefined) {
        if (attribute.minLength > attribute.maxLength) {
          errors.push({ path: '/minLength', message: 'minLength cannot be greater than maxLength' });
        }
      }
    }

    if (attribute.type === 'number' || attribute.type === 'integer') {
      if (attribute.minimum !== undefined && attribute.exclusiveMinimum !== undefined) {
        errors.push({ path: '/minimum', message: 'Cannot have both minimum and exclusiveMinimum' });
      }
      if (attribute.maximum !== undefined && attribute.exclusiveMaximum !== undefined) {
        errors.push({ path: '/maximum', message: 'Cannot have both maximum and exclusiveMaximum' });
      }
      if (attribute.minimum !== undefined && attribute.maximum !== undefined) {
        if (attribute.minimum > attribute.maximum) {
          errors.push({ path: '/minimum', message: 'minimum cannot be greater than maximum' });
        }
      }
    }

    if (attribute.type === 'array') {
      if (attribute.minItems !== undefined && attribute.maxItems !== undefined) {
        if (attribute.minItems > attribute.maxItems) {
          errors.push({ path: '/minItems', message: 'minItems cannot be greater than maxItems' });
        }
      }
      if (attribute.minContains !== undefined && attribute.maxContains !== undefined) {
        if (attribute.minContains > attribute.maxContains) {
          errors.push({ path: '/minContains', message: 'minContains cannot be greater than maxContains' });
        }
      }
    }

    if (attribute.type === 'object') {
      if (attribute.minProperties !== undefined && attribute.maxProperties !== undefined) {
        if (attribute.minProperties > attribute.maxProperties) {
          errors.push({ path: '/minProperties', message: 'minProperties cannot be greater than maxProperties' });
        }
      }
    }

    if (attribute.const !== undefined && attribute.enum !== undefined) {
      errors.push({ path: '/const', message: 'Cannot have both const and enum' });
    }

    if (attribute.readOnly && attribute.writeOnly) {
      errors.push({ path: '/readOnly', message: 'Cannot be both readOnly and writeOnly' });
    }

    return {
      valid: errors.length === 0,
      errors,
    };
  }, []);

  const detectCircularReferences = useCallback((schema, visited = new Set(), path = []) => {
    if (!schema || typeof schema !== 'object') return [];

    const errors = [];

    if (schema.$ref) {
      const refName = schema.$ref.replace('#/$defs/', '');

      if (visited.has(refName)) {
        errors.push({
          path: `/${path.join('/')}`,
          message: `Circular reference detected: ${[...visited, refName].join(' -> ')}`,
          keyword: 'circular-ref',
        });
        return errors;
      }

      return errors;
    }

    if (schema.properties) {
      Object.entries(schema.properties).forEach(([propName, propSchema]) => {
        if (propSchema.$ref) {
          const newVisited = new Set([...visited, path.join('/')]);
          errors.push(...detectCircularReferences(propSchema, newVisited, [...path, propName]));
        }

        if (propSchema.properties) {
          errors.push(...detectCircularReferences(propSchema, visited, [...path, propName]));
        }

        if (propSchema.items) {
          errors.push(...detectCircularReferences(propSchema.items, visited, [...path, propName, 'items']));
        }
      });
    }

    return errors;
  }, []);

  const validateReferences = useCallback((schema, availableClasses = []) => {
    const errors = [];
    const classNames = new Set(availableClasses.map((cls) => cls.name));

    const checkRef = (ref, path) => {
      const className = ref.replace('#/$defs/', '');
      if (!classNames.has(className)) {
        errors.push({
          path,
          message: `Reference to undefined class: ${className}`,
          keyword: 'invalid-ref',
        });
      }
    };

    const traverse = (obj, path = []) => {
      if (!obj || typeof obj !== 'object') return;

      if (obj.$ref) {
        checkRef(obj.$ref, `/${path.join('/')}`);
      }

      if (obj.properties) {
        Object.entries(obj.properties).forEach(([propName, propSchema]) => {
          traverse(propSchema, [...path, propName]);
        });
      }

      if (obj.items) {
        traverse(obj.items, [...path, 'items']);
      }
    };

    traverse(schema);

    return errors;
  }, []);

  const clearErrors = useCallback(() => {
    setValidationErrors([]);
  }, []);

  return {
    validateSchema,
    validateAttribute,
    detectCircularReferences,
    validateReferences,
    validationErrors,
    clearErrors,
  };
};
