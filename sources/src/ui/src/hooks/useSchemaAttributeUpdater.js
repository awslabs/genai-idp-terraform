import { useCallback } from 'react';
import { validateAttribute } from '../components/json-schema-builder/utils/schemaValidators';

export const useSchemaAttributeUpdater = (selectedAttribute, onUpdate) => {
  const safeUpdate = useCallback(
    (updates) => {
      if (!selectedAttribute || !onUpdate) return false;

      const mergedAttribute = { ...selectedAttribute, ...updates };

      Object.keys(updates).forEach((key) => {
        if (updates[key] === undefined) {
          delete mergedAttribute[key];
        }
      });

      const validation = validateAttribute(mergedAttribute);

      if (!validation.valid && validation.errors.length > 0) {
        console.warn('Attribute validation warnings:', validation.errors);
      }

      onUpdate(mergedAttribute);
      return true;
    },
    [selectedAttribute, onUpdate],
  );

  const updateField = useCallback(
    (fieldName, value) => {
      return safeUpdate({ [fieldName]: value });
    },
    [safeUpdate],
  );

  const updateFields = useCallback(
    (fields) => {
      return safeUpdate(fields);
    },
    [safeUpdate],
  );

  const clearField = useCallback(
    (fieldName) => {
      return safeUpdate({ [fieldName]: undefined });
    },
    [safeUpdate],
  );

  return {
    safeUpdate,
    updateField,
    updateFields,
    clearField,
  };
};
