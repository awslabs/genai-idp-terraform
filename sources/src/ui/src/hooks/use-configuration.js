// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

import { useState, useEffect } from 'react';
import { generateClient } from 'aws-amplify/api';
import { ConsoleLogger } from 'aws-amplify/utils';
import getConfigurationQuery from '../graphql/queries/getConfiguration';
import updateConfigurationMutation from '../graphql/queries/updateConfiguration';

const client = generateClient();
const logger = new ConsoleLogger('useConfiguration');

// Utility function to normalize boolean values from strings
const normalizeBooleans = (obj, schema) => {
  if (!obj || !schema) return obj;

  const normalizeValue = (value, propertySchema) => {
    // Handle boolean fields that might be strings
    if (propertySchema?.type === 'boolean') {
      if (typeof value === 'string') {
        if (value.toLowerCase() === 'true') return true;
        if (value.toLowerCase() === 'false') return false;
      }
      return value;
    }

    // Handle objects recursively
    if (value && typeof value === 'object' && !Array.isArray(value) && propertySchema?.properties) {
      const normalized = { ...value };
      Object.keys(normalized).forEach((key) => {
        if (propertySchema.properties[key]) {
          normalized[key] = normalizeValue(normalized[key], propertySchema.properties[key]);
        }
      });
      return normalized;
    }

    // Handle arrays
    if (Array.isArray(value) && propertySchema?.items) {
      return value.map((item) => normalizeValue(item, propertySchema.items));
    }

    return value;
  };

  const normalized = { ...obj };
  if (schema.properties) {
    Object.keys(normalized).forEach((key) => {
      if (schema.properties[key]) {
        normalized[key] = normalizeValue(normalized[key], schema.properties[key]);
      }
    });
  }

  return normalized;
};

// Utility: Get value at path in nested object
const getValueAtPath = (obj, path) => {
  if (!obj || !path) return undefined;
  const segments = path.split(/[.[\]]+/).filter(Boolean);
  return segments.reduce((acc, segment) => {
    if (acc === null || acc === undefined) return undefined;
    return acc[segment];
  }, obj);
};

// Utility: Set value at path in nested object (immutable)
const setValueAtPath = (obj, path, value) => {
  if (!obj || !path) return obj;
  const segments = path.split(/[.[\]]+/).filter(Boolean);
  const result = JSON.parse(JSON.stringify(obj)); // Deep clone

  let current = result;
  for (let i = 0; i < segments.length - 1; i += 1) {
    const segment = segments[i];
    if (!(segment in current)) {
      // Create intermediate object or array
      const nextSegment = segments[i + 1];
      current[segment] = /^\d+$/.test(nextSegment) ? [] : {};
    }
    current = current[segment];
  }

  current[segments[segments.length - 1]] = value;
  return result;
};

// Utility: Compute diff between two configs (returns only changes)
// Note: This only returns CHANGED values, never deletions
// Custom config is always complete, never has missing keys
const getDiff = (oldConfig, newConfig) => {
  const diff = {};

  const computeDiff = (oldObj, newObj, path = []) => {
    // Only check for new or changed keys (no deletions)
    Object.keys(newObj).forEach((key) => {
      const newValue = newObj[key];
      const oldValue = oldObj ? oldObj[key] : undefined;
      const currentPath = [...path, key];

      // Nested objects - recurse
      if (
        newValue &&
        oldValue &&
        typeof newValue === 'object' &&
        typeof oldValue === 'object' &&
        !Array.isArray(newValue) &&
        !Array.isArray(oldValue)
      ) {
        computeDiff(oldValue, newValue, currentPath);
      }
      // Value changed or is new
      else if (JSON.stringify(newValue) !== JSON.stringify(oldValue)) {
        setDiffValue(diff, currentPath, newValue);
      }
    });

    // Note: We do NOT check for deleted keys
    // Custom config should always be complete
    // "Reset to default" means setting the default VALUE, not deleting the key
  };

  const setDiffValue = (obj, path, value) => {
    let current = obj;
    for (let i = 0; i < path.length - 1; i += 1) {
      const segment = path[i];
      if (!(segment in current)) {
        current[segment] = {};
      }
      current = current[segment];
    }
    current[path[path.length - 1]] = value;
  };

  computeDiff(oldConfig, newConfig);
  return diff;
};

const useConfiguration = () => {
  const [schema, setSchema] = useState(null);
  const [defaultConfig, setDefaultConfig] = useState(null);
  const [customConfig, setCustomConfig] = useState(null);
  const [mergedConfig, setMergedConfig] = useState(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState(null);

  const fetchConfiguration = async (silent = false) => {
    // Use different loading states for initial load vs background refresh
    if (silent) {
      setRefreshing(true);
    } else {
      setLoading(true);
    }
    setError(null);
    try {
      logger.debug('Fetching configuration...');
      const result = await client.graphql({ query: getConfigurationQuery });
      logger.debug('API response:', result);

      const response = result.data.getConfiguration;

      if (!response.success) {
        const errorMsg = response.error?.message || 'Failed to load configuration';
        throw new Error(errorMsg);
      }

      const { Schema, Default, Custom } = response;

      // Log raw data types
      logger.debug('Raw data types:', {
        Schema: typeof Schema,
        Default: typeof Default,
        Custom: typeof Custom,
      });

      // Enhanced parsing logic - handle both string and object types
      let schemaObj = Schema;
      let defaultObj = Default;
      let customObj = Custom;

      // Parse schema if it's a string
      if (typeof Schema === 'string') {
        try {
          schemaObj = JSON.parse(Schema);
          logger.debug('Schema parsed from string successfully');
        } catch (e) {
          logger.error('Error parsing schema string:', e);
          throw new Error(`Failed to parse schema data: ${e.message}`);
        }
      }

      // Unwrap nested Schema object if present
      if (schemaObj && schemaObj.Schema) {
        schemaObj = schemaObj.Schema;
        logger.debug('Unwrapped nested Schema object');
      }

      // Parse default config if it's a string
      if (typeof Default === 'string') {
        try {
          defaultObj = JSON.parse(Default);
          logger.debug('Default config parsed from string successfully');
        } catch (e) {
          logger.error('Error parsing default config string:', e);
          throw new Error(`Failed to parse default configuration: ${e.message}`);
        }
      }

      // Parse custom config if it's a string and not null/empty
      if (typeof Custom === 'string' && Custom) {
        try {
          customObj = JSON.parse(Custom);
          logger.debug('Custom config parsed from string successfully');
        } catch (e) {
          logger.error('Error parsing custom config string:', e);
          // Don't throw here, just log the error and use empty object
          customObj = {};
        }
      } else if (!Custom) {
        customObj = {};
      }

      // Debug the parsed objects
      logger.debug('Parsed schema:', schemaObj);
      logger.debug('Parsed default config:', defaultObj);
      logger.debug('Parsed custom config:', customObj);

      // Validate the parsed objects
      if (!schemaObj || typeof schemaObj !== 'object') {
        throw new Error(`Invalid schema data structure ${typeof schemaObj}`);
      }

      if (!defaultObj || typeof defaultObj !== 'object') {
        throw new Error('Invalid default configuration data structure');
      }

      setSchema(schemaObj);

      // Normalize boolean values in both default and custom configs
      const normalizedDefaultObj = normalizeBooleans(defaultObj, schemaObj);
      const normalizedCustomObj = normalizeBooleans(customObj, schemaObj);

      setDefaultConfig(normalizedDefaultObj);
      setCustomConfig(normalizedCustomObj);

      // IMPORTANT: Frontend only uses Custom config
      // Backend ensures Custom is always populated (copies Default on first read)
      // This way frontend always diffs against a complete config
      const activeConfig = normalizedCustomObj;

      console.log('Active configuration (Custom only):', activeConfig);
      // Double check the classification and extraction sections
      if (activeConfig.classification) {
        console.log('Final classification data:', activeConfig.classification);
      }
      if (activeConfig.extraction) {
        console.log('Final extraction data:', activeConfig.extraction);
      }
      if (activeConfig.classes) {
        console.log('Final classes (JSON Schema) data:', activeConfig.classes);
      }
      setMergedConfig(activeConfig);
    } catch (err) {
      logger.error('Error fetching configuration', err);
      setError(`Failed to load configuration: ${err.message}`);
    } finally {
      if (silent) {
        setRefreshing(false);
      } else {
        setLoading(false);
      }
    }
  };

  const updateConfiguration = async (newCustomConfig) => {
    setError(null);
    try {
      logger.debug('Updating config with:', newCustomConfig);

      // Make sure we have a valid object to update with
      const configToUpdate =
        !newCustomConfig || (typeof newCustomConfig === 'object' && Object.keys(newCustomConfig).length === 0)
          ? {} // Use empty object fallback
          : newCustomConfig;

      if (configToUpdate !== newCustomConfig) {
        logger.warn('Attempting to update with empty configuration, using {} as fallback');
      }

      // Ensure we're sending a JSON string
      const configString = typeof configToUpdate === 'string' ? configToUpdate : JSON.stringify(configToUpdate);

      logger.debug('Sending customConfig string:', configString);

      const result = await client.graphql({
        query: updateConfigurationMutation,
        variables: { customConfig: configString },
      });

      const response = result.data.updateConfiguration;

      if (!response.success) {
        const errorMsg = response.error?.message || 'Failed to update configuration';
        throw new Error(errorMsg);
      }

      // Refetch silently to ensure backend and frontend are in sync
      // Silent mode prevents loading state changes that cause re-renders
      // The component will handle rehydration without full re-render
      await fetchConfiguration(true);

      return true;
    } catch (err) {
      logger.error('Error updating configuration', err);
      setError(`Failed to update configuration: ${err.message}`);
      return false;
    }
  };

  // Reset a specific configuration path back to default
  // Frontend computes the new custom config and sends diff to backend
  const resetToDefault = async (path) => {
    if (!path || !customConfig || !defaultConfig) return false;

    setError(null);
    try {
      logger.debug(`Resetting path to default: ${path}`);

      // Get the default value for this path
      const defaultValue = getValueAtPath(defaultConfig, path);
      logger.debug(`Default value at ${path}:`, defaultValue);

      // Create new custom config with default value
      const newCustomConfig = setValueAtPath(customConfig, path, defaultValue);

      // Compute diff between old and new custom config
      const diff = getDiff(customConfig, newCustomConfig);
      logger.debug('Computed diff:', diff);

      // Send only the diff to backend
      const result = await client.graphql({
        query: updateConfigurationMutation,
        variables: { customConfig: JSON.stringify(diff) },
      });

      const response = result.data.updateConfiguration;

      if (!response.success) {
        const errorMsg = response.error?.message || 'Failed to reset to default';
        throw new Error(errorMsg);
      }

      logger.debug(`Successfully reset path ${path} to default`);

      // Optimistic update: update local state immediately
      setCustomConfig(newCustomConfig);
      setMergedConfig(newCustomConfig);

      return true;
    } catch (err) {
      logger.error('Error resetting to default', err);
      setError(`Failed to reset to default: ${err.message}`);
      // Refetch on error to ensure consistency
      await fetchConfiguration(true);
      return false;
    }
  };

  // REMOVED: Old 287-line complex reset logic
  // Now uses simple diff-based approach above

  // Check if a value is customized or default
  const isCustomized = (path) => {
    if (!customConfig || !path) {
      return false;
    }

    try {
      // Split the path into segments, handling array indices properly
      const pathSegments = path.split(/[.[\]]+/).filter(Boolean);

      // Helper function to get value at path segments for comparison
      const getValueAtPathSegments = (obj, segments) => {
        return segments.reduce((acc, segment) => {
          if (acc === null || acc === undefined || !Object.hasOwn(acc, segment)) {
            return undefined;
          }
          return acc[segment];
        }, obj);
      };

      // Get values from both custom and default configs
      const customValue = getValueAtPathSegments(customConfig, pathSegments);
      const defaultValue = getValueAtPathSegments(defaultConfig, pathSegments);

      // First check if the custom value exists
      const customValueExists = customValue !== undefined;

      // Special case for empty objects - they should count as not customized
      if (
        customValueExists &&
        typeof customValue === 'object' &&
        customValue !== null &&
        !Array.isArray(customValue) &&
        Object.keys(customValue).length === 0
      ) {
        return false;
      }

      // Special case for arrays
      if (customValueExists && Array.isArray(customValue)) {
        // Compare arrays for deep equality
        if (Array.isArray(defaultValue)) {
          // Different lengths means customized (including empty vs non-empty)
          if (customValue.length !== defaultValue.length) return true;

          // Deep compare each element
          for (let i = 0; i < customValue.length; i += 1) {
            if (JSON.stringify(customValue[i]) !== JSON.stringify(defaultValue[i])) {
              return true;
            }
          }
          return false; // Arrays are identical
        }
        return true; // Custom is array, default isn't or is undefined
      }

      // Deep compare objects
      if (
        customValueExists &&
        typeof customValue === 'object' &&
        customValue !== null &&
        typeof defaultValue === 'object' &&
        defaultValue !== null
      ) {
        return JSON.stringify(customValue) !== JSON.stringify(defaultValue);
      }

      // Simple value comparison
      return customValueExists && customValue !== defaultValue;
    } catch (err) {
      logger.error(`Error in isCustomized for path: ${path}`, err);
      return false;
    }
  };

  useEffect(() => {
    fetchConfiguration();
  }, []);

  return {
    schema,
    defaultConfig,
    customConfig,
    mergedConfig,
    loading,
    refreshing,
    error,
    fetchConfiguration,
    updateConfiguration,
    resetToDefault,
    isCustomized,
  };
};

export default useConfiguration;
