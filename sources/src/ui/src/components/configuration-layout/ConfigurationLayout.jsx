// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

import React, { useState, useEffect, useRef } from 'react';
import {
  Container,
  Header,
  SpaceBetween,
  Box,
  Button,
  Alert,
  Spinner,
  Form,
  SegmentedControl,
  Modal,
  FormField,
  Input,
  RadioGroup,
  Icon,
} from '@cloudscape-design/components';
import Editor from '@monaco-editor/react';
// eslint-disable-next-line import/no-extraneous-dependencies
import yaml from 'js-yaml';
import ReactMarkdown from 'react-markdown';
import useConfiguration from '../../hooks/use-configuration';
import useConfigurationLibrary from '../../hooks/use-configuration-library';
import useSettingsContext from '../../contexts/settings';
import ConfigBuilder from './ConfigBuilder';
import { deepMerge } from '../../utils/configUtils';

const ConfigurationLayout = () => {
  const {
    schema,
    mergedConfig,
    defaultConfig,
    customConfig,
    loading,
    refreshing,
    error,
    updateConfiguration,
    fetchConfiguration,
    isCustomized,
    resetToDefault,
  } = useConfiguration();

  const [formValues, setFormValues] = useState({});
  const [jsonContent, setJsonContent] = useState('');
  const [yamlContent, setYamlContent] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);
  const [saveError, setSaveError] = useState(null);
  const [importSuccess, setImportSuccess] = useState(false);
  const [validationErrors, setValidationErrors] = useState([]);
  const [viewMode, setViewMode] = useState('form'); // Form view as default
  const [showResetModal, setShowResetModal] = useState(false);
  const [showSaveAsDefaultModal, setShowSaveAsDefaultModal] = useState(false);
  const [showExportModal, setShowExportModal] = useState(false);
  const [exportFormat, setExportFormat] = useState('json');
  const [exportFileName, setExportFileName] = useState('configuration');
  const [importError, setImportError] = useState(null);
  const [extractionSchema, setExtractionSchema] = useState(null);
  const [showMigrationModal, setShowMigrationModal] = useState(false);
  const [pendingImportConfig, setPendingImportConfig] = useState(null);

  // Configuration Library state
  const [showImportSourceModal, setShowImportSourceModal] = useState(false);
  const [showLibraryBrowserModal, setShowLibraryBrowserModal] = useState(false);
  const [showReadmeModal, setShowReadmeModal] = useState(false);
  const [libraryConfigs, setLibraryConfigs] = useState([]);
  const [selectedLibraryConfig, setSelectedLibraryConfig] = useState(null);
  const [readmeContent, setReadmeContent] = useState('');
  const [libraryLoading, setLibraryLoading] = useState(false);

  const editorRef = useRef(null);

  // Hooks for configuration library
  const { listConfigurations, getFile } = useConfigurationLibrary();
  const { settings } = useSettingsContext();

  // Helper function to map IDPPattern to directory name
  const getPatternDirectory = (idpPattern) => {
    if (!idpPattern) return null;

    // Extract pattern number from string like "Pattern1 - Description" or "Pattern2 - Description"
    const match = idpPattern.match(/Pattern(\d+)/i);
    if (match) {
      return `pattern-${match[1]}`;
    }

    return null;
  };

  // Helper function to detect legacy format
  const isLegacyFormat = (config) => {
    if (!config || !config.classes || !Array.isArray(config.classes)) return false;
    if (config.classes.length === 0) return false;

    // Check if first class has legacy attributes format (array instead of object with properties)
    const firstClass = config.classes[0];
    return firstClass.attributes && Array.isArray(firstClass.attributes);
  };

  // Initialize form values from merged config
  useEffect(() => {
    if (mergedConfig) {
      console.log('Setting form values from mergedConfig:', mergedConfig);

      // Make a deep copy to ensure we're not dealing with references
      const formData = JSON.parse(JSON.stringify(mergedConfig));
      setFormValues(formData);

      // Initialize extraction schema from config (stored in classes field)
      if (mergedConfig.classes) {
        setExtractionSchema(mergedConfig.classes);
      }

      // Set both JSON and YAML content
      const jsonString = JSON.stringify(mergedConfig, null, 2);
      setJsonContent(jsonString);

      try {
        const yamlString = yaml.dump(mergedConfig);
        setYamlContent(yamlString);
      } catch (e) {
        console.error('Error converting to YAML:', e);
        setYamlContent('# Error converting to YAML');
      }
    }
  }, [mergedConfig]);

  // Process schema to convert custom types to standard JSON Schema format
  const processSchema = (inputSchema) => {
    try {
      const processedSchema = {
        type: 'object',
        properties: {},
        required: inputSchema.required || [],
      };

      // Process schema properties to handle custom types like 'list'
      if (inputSchema.properties) {
        Object.entries(inputSchema.properties).forEach(([key, prop]) => {
          // Convert 'list' type to proper JSON Schema array type (for backwards compatibility)
          if (prop.type === 'list' || prop.type === 'array') {
            processedSchema.properties[key] = {
              type: 'array',
              items: prop.items || {},
            };

            // Process nested items if they have custom types
            if (prop.items && prop.items.type === 'object' && prop.items.properties) {
              const itemProps = {};
              Object.entries(prop.items.properties).forEach(([itemKey, itemProp]) => {
                if (itemProp.type === 'list' || itemProp.type === 'array') {
                  itemProps[itemKey] = {
                    type: 'array',
                    items: itemProp.items || {},
                  };
                } else if (itemProp.type === 'number' || itemProp.type === 'integer') {
                  // For number types, we'll use a more flexible approach
                  // Instead of using oneOf, we'll just use type: ["number", "string"]
                  // This is more widely supported in JSON Schema implementations
                  itemProps[itemKey] = {
                    type: ['number', 'string'],
                  };

                  // Copy over any constraints
                  if (itemProp.minimum !== undefined) {
                    itemProps[itemKey].minimum = itemProp.minimum;
                  }
                  if (itemProp.maximum !== undefined) {
                    itemProps[itemKey].maximum = itemProp.maximum;
                  }
                } else {
                  itemProps[itemKey] = itemProp;
                }
              });
              processedSchema.properties[key].items.properties = itemProps;
              processedSchema.properties[key].items.required = prop.items.required || [];
            }
          } else if (prop.type === 'number' || prop.type === 'integer') {
            // For number types, we'll use a more flexible approach
            // Instead of using oneOf, we'll just use type: ["number", "string"]
            // This is more widely supported in JSON Schema implementations
            processedSchema.properties[key] = {
              type: ['number', 'string'],
            };

            // Copy over any constraints
            if (prop.minimum !== undefined) {
              processedSchema.properties[key].minimum = prop.minimum;
            }
            if (prop.maximum !== undefined) {
              processedSchema.properties[key].maximum = prop.maximum;
            }
          } else {
            // For non-list types, keep the original schema
            processedSchema.properties[key] = prop;
          }
        });
      }

      return processedSchema;
    } catch (e) {
      console.error('Error processing schema:', e);
      return null;
    }
  };

  // Validate YAML content against the schema
  const validateYamlContent = (yamlString) => {
    if (!schema) return [];

    try {
      // Convert YAML to JSON object
      const parsedYaml = yaml.load(yamlString);
      if (!parsedYaml) return [{ message: 'Empty or invalid YAML content' }];

      // Perform schema validation manually
      const errors = [];

      // Check required fields
      if (schema.required) {
        schema.required.forEach((field) => {
          if (parsedYaml[field] === undefined) {
            errors.push({ message: `Required field '${field}' is missing` });
          }
        });
      }

      // Validate property types and constraints
      if (schema.properties && parsedYaml) {
        Object.entries(schema.properties).forEach(([key, prop]) => {
          const value = parsedYaml[key];

          // Skip validation if value is undefined (already handled by required check)
          if (value === undefined) return;

          // Skip deep validation for classes field - it has its own complex JSON Schema structure
          // Just check it's an array if present
          if (key === 'classes') {
            if (!Array.isArray(value)) {
              errors.push({ message: `Field 'classes' must be an array` });
            }
            return;
          }

          // Type validation
          if (prop.type === 'number' || prop.type === 'integer') {
            // For YAML validation, we'll be more permissive
            // We'll accept any string or number, but we'll still validate constraints
            // if the value can be converted to a number
            if (typeof value !== 'number' && typeof value !== 'string') {
              errors.push({ message: `Field '${key}' must be a number or a string` });
            } else {
              // Try to convert to number for constraint validation
              let numValue;
              let isValidNumber = false;

              if (typeof value === 'number') {
                numValue = value;
                isValidNumber = true;
              } else if (typeof value === 'string') {
                // Try to parse the string as a number
                numValue = parseFloat(value);
                isValidNumber = !Number.isNaN(numValue) && /^-?\d*\.?\d*$/.test(value);
              }

              // Only check constraints if it's a valid number
              if (isValidNumber) {
                if (prop.minimum !== undefined && numValue < prop.minimum) {
                  errors.push({ message: `Field '${key}' must be at least ${prop.minimum}` });
                }
                if (prop.maximum !== undefined && numValue > prop.maximum) {
                  errors.push({ message: `Field '${key}' must be at most ${prop.maximum}` });
                }
              }
            }
          } else if (prop.type === 'string') {
            if (typeof value !== 'string') {
              errors.push({ message: `Field '${key}' must be a string` });
            } else {
              // Check string constraints
              if (prop.minLength !== undefined && value.length < prop.minLength) {
                errors.push({ message: `Field '${key}' must be at least ${prop.minLength} characters` });
              }
              if (prop.maxLength !== undefined && value.length > prop.maxLength) {
                errors.push({ message: `Field '${key}' must be at most ${prop.maxLength} characters` });
              }
              if (prop.pattern && !new RegExp(prop.pattern).test(value)) {
                errors.push({ message: `Field '${key}' does not match required pattern` });
              }
            }
          } else if (prop.type === 'boolean') {
            if (typeof value !== 'boolean') {
              errors.push({ message: `Field '${key}' must be a boolean` });
            }
          } else if (prop.type === 'array' || prop.type === 'list') {
            if (!Array.isArray(value)) {
              errors.push({ message: `Field '${key}' must be an array` });
            } else {
              // Check array constraints
              if (prop.minItems !== undefined && value.length < prop.minItems) {
                errors.push({ message: `Field '${key}' must have at least ${prop.minItems} items` });
              }
              if (prop.maxItems !== undefined && value.length > prop.maxItems) {
                errors.push({ message: `Field '${key}' must have at most ${prop.maxItems} items` });
              }

              // Validate array items if schema is provided
              if (prop.items && prop.items.type && value.length > 0) {
                value.forEach((item, index) => {
                  if (prop.items.type === 'object' && prop.items.properties) {
                    // Validate object properties in array items
                    Object.entries(prop.items.properties).forEach(([itemKey, itemProp]) => {
                      const itemValue = item[itemKey];

                      // Check if required
                      if (prop.items.required && prop.items.required.includes(itemKey) && itemValue === undefined) {
                        errors.push({ message: `Item ${index} in '${key}' is missing required field '${itemKey}'` });
                      }

                      // Type validation for item properties
                      if (itemValue !== undefined) {
                        if (itemProp.type === 'string' && typeof itemValue !== 'string') {
                          errors.push({ message: `Field '${itemKey}' in item ${index} of '${key}' must be a string` });
                        } else if (itemProp.type === 'number' || itemProp.type === 'integer') {
                          // For YAML validation, we'll be more permissive
                          if (typeof itemValue !== 'number' && typeof itemValue !== 'string') {
                            errors.push({
                              message: `Field '${itemKey}' in item ${index} of '${key}' must be a number or a string`,
                            });
                          } else {
                            // Try to convert to number for constraint validation
                            let numValue;
                            let isValidNumber = false;

                            if (typeof itemValue === 'number') {
                              numValue = itemValue;
                              isValidNumber = true;
                            } else if (typeof itemValue === 'string') {
                              // Try to parse the string as a number
                              numValue = parseFloat(itemValue);
                              isValidNumber = !Number.isNaN(numValue) && /^-?\d*\.?\d*$/.test(itemValue);
                            }

                            // Only check constraints if it's a valid number
                            if (isValidNumber && itemProp.minimum !== undefined && numValue < itemProp.minimum) {
                              errors.push({
                                message: `Field '${itemKey}' in item ${index} of '${key}' must be ` + `at least ${itemProp.minimum}`,
                              });
                            }
                            if (isValidNumber && itemProp.maximum !== undefined && numValue > itemProp.maximum) {
                              errors.push({
                                message: `Field '${itemKey}' in item ${index} of '${key}' must be ` + `at most ${itemProp.maximum}`,
                              });
                            }
                          }
                        } else if (itemProp.type === 'boolean' && typeof itemValue !== 'boolean') {
                          errors.push({ message: `Field '${itemKey}' in item ${index} of '${key}' must be a boolean` });
                        }
                      }
                    });
                  } else if (prop.items.type === 'string' && typeof item !== 'string') {
                    errors.push({ message: `Item ${index} in '${key}' must be a string` });
                  } else if (prop.items.type === 'number' || prop.items.type === 'integer') {
                    // For YAML validation, we'll be more permissive
                    if (typeof item !== 'number' && typeof item !== 'string') {
                      errors.push({
                        message: `Item ${index} in '${key}' must be a number or a string`,
                      });
                    } else {
                      // Try to convert to number for constraint validation
                      let numValue;
                      let isValidNumber = false;

                      if (typeof item === 'number') {
                        numValue = item;
                        isValidNumber = true;
                      } else if (typeof item === 'string') {
                        // Try to parse the string as a number
                        numValue = parseFloat(item);
                        isValidNumber = !Number.isNaN(numValue) && /^-?\d*\.?\d*$/.test(item);
                      }

                      // Only check constraints if it's a valid number
                      if (isValidNumber && prop.items.minimum !== undefined && numValue < prop.items.minimum) {
                        errors.push({
                          message: `Item ${index} in '${key}' must be at least ${prop.items.minimum}`,
                        });
                      }
                      if (isValidNumber && prop.items.maximum !== undefined && numValue > prop.items.maximum) {
                        errors.push({
                          message: `Item ${index} in '${key}' must be at most ${prop.items.maximum}`,
                        });
                      }
                    }
                  } else if (prop.items.type === 'boolean' && typeof item !== 'boolean') {
                    errors.push({ message: `Item ${index} in '${key}' must be a boolean` });
                  }
                });
              }
            }
          } else if (prop.type === 'object') {
            if (typeof value !== 'object' || value === null || Array.isArray(value)) {
              errors.push({ message: `Field '${key}' must be an object` });
            } else if (prop.properties) {
              // Validate nested object properties
              Object.entries(prop.properties).forEach(([nestedKey]) => {
                const nestedValue = value[nestedKey];

                // Check if required
                if (prop.required && prop.required.includes(nestedKey) && nestedValue === undefined) {
                  errors.push({ message: `Object '${key}' is missing required field '${nestedKey}'` });
                }
              });
            }
          }

          // Check enum values
          if (prop.enum && !prop.enum.includes(value)) {
            errors.push({ message: `Field '${key}' must be one of: ${prop.enum.join(', ')}` });
          }
        });
      }

      return errors;
    } catch (e) {
      return [{ message: `Invalid YAML: ${e.message}` }];
    }
  };

  const handleEditorDidMount = (editor, monaco) => {
    editorRef.current = editor;

    // Set up JSON schema validation if schema is available
    if (schema) {
      try {
        // Process the schema once
        const processedSchema = processSchema(schema);

        if (processedSchema) {
          // Create the JSON Schema configuration
          const jsonSchema = {
            uri: 'http://myserver/schema.json',
            fileMatch: ['*'],
            schema: processedSchema,
          };

          // Set the diagnostics options with the processed schema for JSON
          monaco.languages.json.jsonDefaults.setDiagnosticsOptions({
            validate: true,
            schemas: [jsonSchema],
            allowComments: false,
            trailingCommas: 'error',
          });

          console.log('Processed JSON Schema:', processedSchema);

          // For YAML, we'll use manual validation in the onChange handler
          // since Monaco doesn't have built-in YAML schema validation
          if (viewMode === 'yaml') {
            // Initial validation of YAML content
            const yamlErrors = validateYamlContent(yamlContent);
            if (yamlErrors.length > 0) {
              setValidationErrors(yamlErrors);
            }
          }
        }
      } catch (e) {
        console.error('Error setting up schema validation:', e);
      }
    }
  };

  // Handle changes in the JSON editor
  const handleJsonEditorChange = (value) => {
    setJsonContent(value);
    try {
      const parsedValue = JSON.parse(value);
      setFormValues(parsedValue);

      // Update YAML when JSON changes
      try {
        const yamlString = yaml.dump(parsedValue);
        setYamlContent(yamlString);
      } catch (yamlErr) {
        console.error('Error converting to YAML:', yamlErr);
      }

      setValidationErrors([]);
    } catch (e) {
      setValidationErrors([{ message: `Invalid JSON: ${e.message}` }]);
    }
  };

  // Handle changes in the YAML editor
  const handleYamlEditorChange = (value) => {
    setYamlContent(value);
    try {
      const parsedValue = yaml.load(value);
      setFormValues(parsedValue);

      // Update JSON when YAML changes
      try {
        const jsonString = JSON.stringify(parsedValue, null, 2);
        setJsonContent(jsonString);
      } catch (jsonErr) {
        console.error('Error converting to JSON:', jsonErr);
      }

      // Validate YAML against schema
      if (schema) {
        const schemaErrors = validateYamlContent(value);
        setValidationErrors(schemaErrors);
      } else {
        setValidationErrors([]);
      }
    } catch (e) {
      setValidationErrors([{ message: `Invalid YAML: ${e.message}` }]);
    }
  };

  // Validate the current content based on view mode
  const validateCurrentContent = () => {
    if (!schema) return [];

    try {
      if (viewMode === 'json') {
        // For JSON, we rely on Monaco's built-in validation
        // But we can do a basic parse check here
        JSON.parse(jsonContent);
        return [];
      }
      if (viewMode === 'yaml') {
        // For YAML, use our custom validation
        return validateYamlContent(yamlContent);
      }
      return [];
    } catch (e) {
      return [{ message: `Invalid ${viewMode.toUpperCase()}: ${e.message}` }];
    }
  };

  const handleSave = async (saveAsDefault = false) => {
    // Validate content before saving
    const currentErrors = validateCurrentContent();

    if (currentErrors.length > 0) {
      setValidationErrors(currentErrors);
      setSaveError('Cannot save: Configuration contains validation errors');
      return;
    }

    setIsSaving(true);
    setSaveSuccess(false);
    setSaveError(null);

    try {
      // Simpler approach: Just compare the current form values with default values
      // and only include differences in our custom config
      const customConfigToSave = {};

      // Helper function to compare values - returns a new object
      const compareWithDefault = (current, defaultObj, path = '') => {
        // Add debugging for granular assessment
        if (path.includes('granular')) {
          console.log(`DEBUG: compareWithDefault called with path '${path}':`, {
            // nosemgrep: javascript.lang.security.audit.unsafe-formatstring.unsafe-formatstring - Debug logging with controlled internal data
            current,
            currentType: typeof current,
            defaultObj,
            defaultType: typeof defaultObj,
            currentIsNull: current === null,
            currentIsUndefined: current === undefined,
            defaultIsNull: defaultObj === null,
            defaultIsUndefined: defaultObj === undefined,
          });
        }

        // Make a new result object each time to avoid mutation
        const newResult = {};

        // Skip comparison for null/undefined objects (but not false values!)
        if (current === null || current === undefined || defaultObj === null || defaultObj === undefined) {
          // If current exists but default doesn't, this is a customization
          if (current !== null && current !== undefined && (defaultObj === null || defaultObj === undefined)) {
            return { [path]: current };
          }
          return {};
        }

        // Handle different types
        if (typeof current !== typeof defaultObj) {
          return { [path]: current };
        }

        // Handle arrays
        if (Array.isArray(current)) {
          if (!Array.isArray(defaultObj)) {
            return { [path]: current };
          }

          // Special case: if current array is empty but default is not empty,
          // we need to explicitly save the empty array to override the default
          if (current.length === 0 && defaultObj.length > 0) {
            return { [path]: current };
          }

          // If lengths are different, arrays are different
          if (current.length !== defaultObj.length) {
            return { [path]: current };
          }

          // Check each array element
          let isDifferent = false;
          for (let i = 0; i < current.length; i += 1) {
            // Use += 1 instead of ++
            // For objects in arrays, recursively compare
            if (typeof current[i] === 'object' && current[i] !== null && typeof defaultObj[i] === 'object' && defaultObj[i] !== null) {
              const nestedPath = path ? `${path}[${i}]` : `[${i}]`;
              const nestedDiff = compareWithDefault(current[i], defaultObj[i], nestedPath);

              if (Object.keys(nestedDiff).length > 0) {
                isDifferent = true;
                // No need to continue, we know the array is different
                break;
              }
            }
            // For primitive values, direct compare
            else if (JSON.stringify(current[i]) !== JSON.stringify(defaultObj[i])) {
              isDifferent = true;
              break;
            }
          }

          if (isDifferent) {
            return { [path]: current };
          }
          return {};
        }

        // Handle objects (non-arrays)
        if (typeof current === 'object') {
          const keys = new Set([...Object.keys(current), ...Object.keys(defaultObj)]);
          let allResults = {};

          keys.forEach((key) => {
            const newPath = path ? `${path}.${key}` : key;

            // Add debugging for granular assessment
            if (newPath.includes('granular')) {
              console.log(`DEBUG: Comparing object key '${key}' at path '${newPath}':`, {
                // nosemgrep: javascript.lang.security.audit.unsafe-formatstring.unsafe-formatstring - Debug logging with controlled internal data
                currentValue: current[key],
                defaultValue: defaultObj[key],
                keyInCurrent: key in current,
                keyInDefault: key in defaultObj,
              });
            }

            // If key exists in current but not in default
            if (!(key in defaultObj) && key in current) {
              allResults = { ...allResults, [newPath]: current[key] };
            }
            // If key exists in both, compare recursively
            else if (key in defaultObj && key in current) {
              const nestedResults = compareWithDefault(current[key], defaultObj[key], newPath);

              // Add debugging for granular assessment
              if (newPath.includes('granular')) {
                console.log(`DEBUG: Recursive call result for '${newPath}':`, {
                  // nosemgrep: javascript.lang.security.audit.unsafe-formatstring.unsafe-formatstring - Debug logging with controlled internal data
                  nestedResults,
                  nestedResultsKeys: Object.keys(nestedResults),
                  nestedResultsLength: Object.keys(nestedResults).length,
                });
              }

              allResults = { ...allResults, ...nestedResults };
            }
          });

          return allResults;
        }

        // Handle primitive values
        if (current !== defaultObj) {
          console.log(`DEBUG: Primitive difference detected at path '${path}':`, {
            // nosemgrep: javascript.lang.security.audit.unsafe-formatstring.unsafe-formatstring - Debug logging with controlled internal data
            current,
            currentType: typeof current,
            defaultObj,
            defaultType: typeof defaultObj,
            areEqual: current === defaultObj,
            areStrictEqual: current !== defaultObj,
          });
          const result = { [path]: current };
          console.log(`DEBUG: Returning primitive difference result:`, result);
          return result;
        }

        return newResult;
      };

      let configToSave;

      if (saveAsDefault) {
        // When saving as default, merge form changes with complete Custom config
        // This ensures we capture both:
        // 1. User's form edits (formValues)
        // 2. Fields not in form like notes, system_prompt, task_prompt (from customConfig)
        const mergedConfigToSave = deepMerge(customConfig || {}, formValues);
        configToSave = { ...mergedConfigToSave, saveAsDefault: true };
        console.log('Saving merged config as new Default:', configToSave);
      } else {
        // CRITICAL: Compare formValues against customConfig (what we loaded)
        // This ensures we only send actual changes as the diff
        // Backend will merge this diff into existing Custom, preserving all other fields
        console.log('DEBUG: About to compare formValues with customConfig:', {
          formValues,
          customConfig,
          granularInFormValues: formValues?.assessment?.granular,
          granularInCustomConfig: customConfig?.assessment?.granular,
        });
        const differences = compareWithDefault(formValues, customConfig);
        console.log('DEBUG: Differences found by compareWithDefault:', differences);

        // Flatten path results into a proper object structure - revised to avoid ESLint errors
        const buildObjectFromPaths = (paths) => {
          // Create a fresh result object
          const newResult = {};

          Object.entries(paths).forEach(([path, value]) => {
            if (!path) return; // Skip empty paths

            // For paths with dots, build nested structure
            if (path.includes('.') || path.includes('[')) {
              // Handle array notation
              if (path.includes('[')) {
                // Arrays need special handling
                // This is simplified - we'll include the whole array when it's customized
                const arrayPath = path.split('[')[0];
                if (!Object.prototype.hasOwnProperty.call(newResult, arrayPath)) {
                  // Find the array in formValues
                  const arrayValue = path.split('.').reduce((acc, part) => {
                    if (!acc) return undefined;
                    return acc[part.replace(/\[\d+\]$/, '')];
                  }, formValues);

                  if (arrayValue) {
                    // Create a new object with this property
                    Object.assign(newResult, { [arrayPath]: arrayValue });
                  }
                }
              } else {
                // Regular object paths
                const parts = path.split('.');

                // Build an object to merge
                const objectToMerge = {};
                let current = objectToMerge;

                // Build nested structure without modifying existing objects
                for (let i = 0; i < parts.length - 1; i += 1) {
                  // Use += 1 instead of ++
                  current[parts[i]] = {};
                  current = current[parts[i]]; // nosemgrep: javascript.lang.security.audit.prototype-pollution.prototype-pollution-loop.prototype-pollution-loop - Index from controlled array iteration
                }

                // Set the value at the final path - IMPORTANT: preserve boolean false values!
                current[parts[parts.length - 1]] = value;

                // Deep merge this into result
                const deepMergeNested = (target, source) => {
                  const output = { ...target };

                  Object.keys(source).forEach((key) => {
                    if (source[key] && typeof source[key] === 'object' && !Array.isArray(source[key])) {
                      if (target[key] && typeof target[key] === 'object') {
                        output[key] = deepMergeNested(target[key], source[key]);
                      } else {
                        output[key] = { ...source[key] };
                      }
                    } else {
                      // CRITICAL FIX: Always set the value, including boolean false
                      output[key] = source[key];
                    }
                  });

                  return output;
                };

                // Merge into result without modifying original objects
                Object.assign(newResult, deepMergeNested(newResult, objectToMerge));
              }
            } else {
              // For top-level values, create a new object with the property
              Object.assign(newResult, { [path]: value });
            }
          });

          return newResult;
        };

        // Convert the difference paths to a proper nested structure
        const builtObject = buildObjectFromPaths(differences);
        console.log('DEBUG: Built object from paths:', builtObject);

        // CRITICAL: Always include the current document schema (classes) if it exists OR is explicitly empty
        // This ensures empty arrays are saved (to wipe all classes) and prevents schema loss
        if (formValues.classes && Array.isArray(formValues.classes)) {
          builtObject.classes = formValues.classes;
          console.log('DEBUG: Including document schema (classes) in save:', formValues.classes);
        }

        // CRITICAL: If there are no differences AND no schema changes, don't send update to backend
        // This prevents unnecessary API calls and potential data issues
        if (Object.keys(builtObject).length === 0) {
          console.log('No changes detected, skipping save');
          setSaveSuccess(true);
          setTimeout(() => setSaveSuccess(false), 3000);
          return;
        }

        Object.assign(customConfigToSave, builtObject);
        configToSave = customConfigToSave;
        console.log('Saving customized config:', configToSave);
      }

      const success = await updateConfiguration(configToSave);

      if (success) {
        setSaveSuccess(true);
        if (saveAsDefault) {
          setShowSaveAsDefaultModal(false);
        }
      } else {
        setSaveError('Failed to save configuration. Please try again.');
      }
    } catch (err) {
      console.error('Save error:', err);
      setSaveError(`Error: ${err.message}`);
    } finally {
      setIsSaving(false);
    }
  };

  const handleFormChange = (newValues) => {
    setFormValues(newValues);
    try {
      // Update both JSON and YAML content
      const jsonString = JSON.stringify(newValues, null, 2);
      setJsonContent(jsonString);

      try {
        const yamlString = yaml.dump(newValues);
        setYamlContent(yamlString);
      } catch (yamlErr) {
        console.error('Error converting to YAML:', yamlErr);
      }

      setValidationErrors([]);
    } catch (e) {
      setValidationErrors([{ message: `Error converting form values to JSON: ${e.message}` }]);
    }
  };

  const formatJson = () => {
    if (editorRef.current && viewMode === 'json') {
      editorRef.current.getAction('editor.action.formatDocument').run();
    }
  };

  const formatYaml = () => {
    if (editorRef.current && viewMode === 'yaml') {
      editorRef.current.getAction('editor.action.formatDocument').run();

      // Re-validate after formatting
      setTimeout(() => {
        const errors = validateYamlContent(yamlContent);
        setValidationErrors(errors);
      }, 100);
    }
  };

  const handleResetAllToDefault = async () => {
    setIsSaving(true);
    setSaveSuccess(false);
    setSaveError(null);

    try {
      // Reset custom configuration by sending a special reset flag
      // Backend will clear Custom, and on next read it will copy Default -> Custom
      const success = await updateConfiguration({ resetToDefault: true });

      if (success) {
        setSaveSuccess(true);
        setShowResetModal(false);
      } else {
        setSaveError('Failed to reset configuration. Please try again.');
      }
    } catch (err) {
      console.error('Reset error:', err);
      setSaveError(`Error: ${err.message}`);
    } finally {
      setIsSaving(false);
    }
  };

  const handleExport = () => {
    try {
      let content;
      let mimeType;
      let fileExtension;

      if (exportFormat === 'yaml') {
        content = yaml.dump(mergedConfig);
        mimeType = 'text/yaml';
        fileExtension = 'yaml';
      } else {
        content = JSON.stringify(mergedConfig, null, 2);
        mimeType = 'application/json';
        fileExtension = 'json';
      }

      const blob = new Blob([content], { type: mimeType });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `${exportFileName}.${fileExtension}`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
      setShowExportModal(false);
    } catch (err) {
      setSaveError(`Export failed: ${err.message}`);
    }
  };

  const handleImport = (event) => {
    const file = event.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        setImportError(null);
        const content = e.target.result;

        const importedConfig = file.name.endsWith('.yaml') || file.name.endsWith('.yml') ? yaml.load(content) : JSON.parse(content);

        if (importedConfig && typeof importedConfig === 'object') {
          // Check if config is in legacy format
          if (isLegacyFormat(importedConfig)) {
            // Show migration modal and store config for later
            setPendingImportConfig(importedConfig);
            setShowMigrationModal(true);
          } else {
            // Modern format - load directly into form
            if (importedConfig.classes) {
              setExtractionSchema(importedConfig.classes);
            }
            handleFormChange(importedConfig);
            setSaveSuccess(false);
            setSaveError(null);
          }
        } else {
          setImportError('Invalid configuration file format');
        }
      } catch (err) {
        setImportError(`Import failed: ${err.message}`);
      }
    };
    reader.readAsText(file);
    // Clear the input value to allow re-importing the same file
    event.target.value = '';
  };

  const handleMigrationConfirm = async () => {
    if (!pendingImportConfig) return;

    setIsSaving(true);
    try {
      // Send to backend for migration, then reload to get migrated version
      const success = await updateConfiguration(pendingImportConfig);

      if (success) {
        await fetchConfiguration();
        setShowMigrationModal(false);
        setPendingImportConfig(null);
      } else {
        setImportError('Failed to import configuration');
        setShowMigrationModal(false);
      }
    } catch (err) {
      setImportError(`Import failed: ${err.message}`);
      setShowMigrationModal(false);
    } finally {
      setIsSaving(false);
    }
  };

  const handleMigrationCancel = () => {
    setShowMigrationModal(false);
    setPendingImportConfig(null);
  };

  // Handler for Import button click - show source selection modal
  const handleImportClick = () => {
    setShowImportSourceModal(true);
  };

  // Handler for local file import
  const handleLocalFileImport = () => {
    setShowImportSourceModal(false);
    document.getElementById('import-file').click();
  };

  // Handler for library import
  const handleLibraryImport = async () => {
    setShowImportSourceModal(false);
    setLibraryLoading(true);

    try {
      const patternDir = getPatternDirectory(settings?.IDPPattern);
      if (!patternDir) {
        setImportError('Pattern not configured in settings');
        setLibraryLoading(false);
        return;
      }

      const configs = await listConfigurations(patternDir);
      setLibraryConfigs(configs);
      setShowLibraryBrowserModal(true);
    } catch (err) {
      setImportError(`Failed to load library: ${err.message}`);
    } finally {
      setLibraryLoading(false);
    }
  };

  // Handler for selecting a library config
  const handleSelectLibraryConfig = async (config) => {
    setSelectedLibraryConfig(config);

    if (config.hasReadme) {
      // Fetch and show README
      const patternDir = getPatternDirectory(settings?.IDPPattern);
      const file = await getFile(patternDir, config.name, 'README.md');

      if (file) {
        setReadmeContent(file.content);
        setShowLibraryBrowserModal(false);
        setShowReadmeModal(true);
      } else {
        // No README or error, import directly
        await importFromLibrary(config);
      }
    } else {
      // No README, import directly
      await importFromLibrary(config);
    }
  };

  // Handler to import configuration from library
  const importFromLibrary = async (config) => {
    setShowReadmeModal(false);
    setShowLibraryBrowserModal(false);

    try {
      const patternDir = getPatternDirectory(settings?.IDPPattern);

      // Use the detected file type from the config object
      const fileName = config.configFileType === 'json' ? 'config.json' : 'config.yaml';
      const file = await getFile(patternDir, config.name, fileName);

      if (!file) {
        setImportError('Failed to load configuration file');
        return;
      }

      // Parse based on file type
      const importedConfig = fileName.endsWith('.json') ? JSON.parse(file.content) : yaml.load(file.content);

      if (importedConfig && typeof importedConfig === 'object') {
        if (isLegacyFormat(importedConfig)) {
          setPendingImportConfig(importedConfig);
          setShowMigrationModal(true);
        } else {
          if (importedConfig.classes) {
            setExtractionSchema(importedConfig.classes);
          }
          handleFormChange(importedConfig);
          setSaveSuccess(false);
          setSaveError(null);
          setImportSuccess(true);
          // Auto-dismiss after 3 seconds
          setTimeout(() => setImportSuccess(false), 3000);
        }
      } else {
        setImportError('Invalid configuration format');
      }
    } catch (err) {
      setImportError(`Import failed: ${err.message}`);
    }
  };

  if (loading) {
    return (
      <Container header={<Header variant="h2">Configuration</Header>}>
        <Box textAlign="center" padding="l">
          <Spinner size="large" />
          <Box padding="s">Loading configuration...</Box>
        </Box>
      </Container>
    );
  }

  if (error) {
    return (
      <Container header={<Header variant="h2">Configuration</Header>}>
        <Alert type="error" header="Error loading configuration">
          <SpaceBetween size="s">
            <div>{error}</div>
            <Box>
              <Button onClick={fetchConfiguration} variant="primary">
                Retry
              </Button>
            </Box>
          </SpaceBetween>
        </Alert>
      </Container>
    );
  }

  if (!schema || !mergedConfig) {
    return (
      <Container header={<Header variant="h2">Configuration</Header>}>
        <Alert type="error" header="Configuration not available">
          <SpaceBetween size="s">
            <div>Unable to load configuration schema or values.</div>
            <Box>
              <Button onClick={fetchConfiguration} variant="primary">
                Retry
              </Button>
            </Box>
          </SpaceBetween>
        </Alert>
      </Container>
    );
  }

  return (
    <>
      <Modal
        visible={showResetModal}
        onDismiss={() => setShowResetModal(false)}
        header="Reset All to Default"
        footer={
          <Box float="right">
            <SpaceBetween direction="horizontal" size="xs">
              <Button variant="link" onClick={() => setShowResetModal(false)}>
                Cancel
              </Button>
              <Button variant="primary" onClick={handleResetAllToDefault} loading={isSaving}>
                Reset
              </Button>
            </SpaceBetween>
          </Box>
        }
      >
        <Box variant="span">Are you sure you want to reset all configuration settings to default values? This action cannot be undone.</Box>
      </Modal>

      <Modal
        visible={showSaveAsDefaultModal}
        onDismiss={() => setShowSaveAsDefaultModal(false)}
        header="Save as New Default"
        footer={
          <Box float="right">
            <SpaceBetween direction="horizontal" size="xs">
              <Button variant="link" onClick={() => setShowSaveAsDefaultModal(false)}>
                Cancel
              </Button>
              <Button variant="primary" onClick={() => handleSave(true)} loading={isSaving}>
                Save as Default
              </Button>
            </SpaceBetween>
          </Box>
        }
      >
        <SpaceBetween direction="vertical" size="m">
          <Box variant="span">
            Are you sure you want to save the current configuration as the new default? This will replace the existing default configuration
            and cannot be undone.
          </Box>
          <Alert type="warning" header="Important: Version upgrade considerations">
            The default configuration may be overwritten when you update the solution to a new version. We recommend using the Export button
            to download and save your configuration so you can easily restore it after an upgrade if needed.
          </Alert>
        </SpaceBetween>
      </Modal>

      <Modal
        visible={showExportModal}
        onDismiss={() => setShowExportModal(false)}
        header="Export Configuration"
        footer={
          <Box float="right">
            <SpaceBetween direction="horizontal" size="xs">
              <Button variant="link" onClick={() => setShowExportModal(false)}>
                Cancel
              </Button>
              <Button variant="primary" onClick={handleExport}>
                Export
              </Button>
            </SpaceBetween>
          </Box>
        }
      >
        <SpaceBetween direction="vertical" size="l">
          <FormField label="File format">
            <RadioGroup
              value={exportFormat}
              onChange={({ detail }) => setExportFormat(detail.value)}
              items={[
                { value: 'json', label: 'JSON' },
                { value: 'yaml', label: 'YAML' },
              ]}
            />
          </FormField>
          <FormField label="File name">
            <Input value={exportFileName} onChange={({ detail }) => setExportFileName(detail.value)} placeholder="configuration" />
          </FormField>
        </SpaceBetween>
      </Modal>

      <Modal
        visible={showMigrationModal}
        onDismiss={handleMigrationCancel}
        header="Configuration Migration Required"
        footer={
          <Box float="right">
            <SpaceBetween direction="horizontal" size="xs">
              <Button variant="link" onClick={handleMigrationCancel}>
                Cancel
              </Button>
              <Button variant="primary" onClick={handleMigrationConfirm} loading={isSaving}>
                Save and Migrate
              </Button>
            </SpaceBetween>
          </Box>
        }
      >
        <SpaceBetween direction="vertical" size="m">
          <Box variant="span">
            The configuration file you are importing uses a legacy format that needs to be migrated to the current JSON Schema format.
          </Box>
          <Alert type="info" header="What will happen">
            <ul>
              <li>The configuration will be automatically converted to the new format</li>
              <li>All your settings and document classes will be preserved</li>
              <li>The migrated configuration will be saved to the database</li>
              <li>You can review the changes after migration</li>
            </ul>
          </Alert>
          <Box variant="span">
            Click &quot;Save and Migrate&quot; to proceed with the migration, or &quot;Cancel&quot; to abort the import.
          </Box>
        </SpaceBetween>
      </Modal>

      {/* Import Source Selection Modal */}
      <Modal
        visible={showImportSourceModal}
        onDismiss={() => setShowImportSourceModal(false)}
        header="Choose Import Source"
        footer={
          <Box float="right">
            <Button variant="link" onClick={() => setShowImportSourceModal(false)}>
              Cancel
            </Button>
          </Box>
        }
      >
        <SpaceBetween size="l">
          <Button variant="primary" onClick={handleLocalFileImport} iconName="upload" fullWidth>
            Import from Local File
          </Button>
          <Button variant="normal" onClick={handleLibraryImport} iconName="folder" fullWidth loading={libraryLoading}>
            Import from Configuration Library
          </Button>
        </SpaceBetween>
      </Modal>

      {/* Configuration Library Browser Modal */}
      <Modal
        visible={showLibraryBrowserModal}
        onDismiss={() => setShowLibraryBrowserModal(false)}
        header={`Configuration Library - ${settings?.IDPPattern || 'Pattern'}`}
        size="large"
        footer={
          <Box float="right">
            <Button variant="link" onClick={() => setShowLibraryBrowserModal(false)}>
              Cancel
            </Button>
          </Box>
        }
      >
        <SpaceBetween size="m">
          {libraryConfigs.length === 0 && (
            <Alert type="info">No configurations found for {settings?.IDPPattern} in the Config Library</Alert>
          )}

          {libraryConfigs.map((config) => (
            <Container key={config.name}>
              <SpaceBetween size="xs">
                <Box fontSize="heading-m" fontWeight="bold">
                  {config.name}
                </Box>
                <SpaceBetween size="xs" direction="horizontal">
                  <Box fontSize="body-s" color="text-body-secondary">
                    Format: {config.configFileType?.toUpperCase() || 'YAML'}
                  </Box>
                  {config.hasReadme && (
                    <Box fontSize="body-s" color="text-status-info">
                      <Icon name="file" /> README available
                    </Box>
                  )}
                </SpaceBetween>
                <Box float="right">
                  <Button variant="primary" onClick={() => handleSelectLibraryConfig(config)}>
                    Select
                  </Button>
                </Box>
              </SpaceBetween>
            </Container>
          ))}
        </SpaceBetween>
      </Modal>

      {/* README Preview Modal */}
      <Modal
        visible={showReadmeModal}
        onDismiss={() => setShowReadmeModal(false)}
        header={`Configuration: ${selectedLibraryConfig?.name}`}
        size="large"
        footer={
          <Box float="right">
            <SpaceBetween direction="horizontal" size="xs">
              <Button
                variant="link"
                onClick={() => {
                  setShowReadmeModal(false);
                  setShowLibraryBrowserModal(true);
                }}
              >
                Go Back
              </Button>
              <Button variant="primary" onClick={() => importFromLibrary(selectedLibraryConfig)}>
                Import This Configuration
              </Button>
            </SpaceBetween>
          </Box>
        }
      >
        <Box padding="l">
          <ReactMarkdown>{readmeContent}</ReactMarkdown>
        </Box>
      </Modal>

      <Container
        header={
          <Header
            variant="h2"
            actions={
              <SpaceBetween direction="horizontal" size="xs">
                <SegmentedControl
                  selectedId={viewMode}
                  onChange={({ detail }) => setViewMode(detail.selectedId)}
                  options={[
                    { id: 'form', text: 'Form View' },
                    { id: 'json', text: 'JSON View' },
                    { id: 'yaml', text: 'YAML View' },
                  ]}
                />
                {viewMode === 'json' && (
                  <Button onClick={formatJson} iconName="file">
                    Format JSON
                  </Button>
                )}
                {viewMode === 'yaml' && (
                  <Button onClick={formatYaml} iconName="file">
                    Format YAML
                  </Button>
                )}
                <Button variant="normal" onClick={() => setShowExportModal(true)}>
                  Export
                </Button>
                <Button variant="normal" onClick={handleImportClick}>
                  Import
                </Button>
                <input id="import-file" type="file" accept=".json,.yaml,.yml" style={{ display: 'none' }} onChange={handleImport} />
                <Button variant="normal" onClick={() => setShowResetModal(true)}>
                  Restore default (All)
                </Button>
                <Button variant="normal" onClick={() => setShowSaveAsDefaultModal(true)}>
                  Save as default
                </Button>
                <Button variant="primary" onClick={() => handleSave(false)} loading={isSaving}>
                  Save changes
                </Button>
              </SpaceBetween>
            }
          >
            Configuration
          </Header>
        }
      >
        <Form>
          {refreshing && (
            <Alert type="info" header="Syncing configuration...">
              <Box display="flex" alignItems="center">
                <Spinner size="normal" />
                <Box margin={{ left: 's' }}>Refreshing data from server</Box>
              </Box>
            </Alert>
          )}

          {saveSuccess && (
            <Alert type="success" dismissible onDismiss={() => setSaveSuccess(false)} header="Configuration saved successfully">
              Your configuration changes have been saved.
            </Alert>
          )}

          {importSuccess && (
            <Alert type="success" dismissible onDismiss={() => setImportSuccess(false)} header="Configuration imported successfully">
              The configuration has been imported from the library and loaded into the editor.
            </Alert>
          )}

          {saveError && (
            <Alert type="error" dismissible onDismiss={() => setSaveError(null)} header="Error saving configuration">
              {saveError}
            </Alert>
          )}

          {importError && (
            <Alert type="error" dismissible onDismiss={() => setImportError(null)} header="Import error">
              {importError}
            </Alert>
          )}

          {validationErrors.length > 0 && (
            <Alert type="warning" header="Validation errors">
              <ul>
                {validationErrors.map((e, index) => (
                  // eslint-disable-next-line react/no-array-index-key
                  <li key={index}>{e.message}</li>
                ))}
              </ul>
            </Alert>
          )}

          <Box padding="s">
            {viewMode === 'form' && (
              <ConfigBuilder
                schema={{
                  ...schema,
                  properties: Object.fromEntries(Object.entries(schema?.properties || {}).filter(([key]) => key !== 'classes')),
                }}
                formValues={formValues}
                defaultConfig={defaultConfig}
                isCustomized={isCustomized}
                onResetToDefault={resetToDefault}
                onChange={handleFormChange}
                extractionSchema={extractionSchema}
                onSchemaChange={(schemaData, isDirty) => {
                  setExtractionSchema(schemaData);
                  if (isDirty) {
                    const updatedConfig = { ...formValues };
                    // CRITICAL: Always set classes, even if empty array (to support wipe all functionality)
                    // Handle null (no classes) by setting empty array
                    if (schemaData === null) {
                      updatedConfig.classes = [];
                    } else if (Array.isArray(schemaData)) {
                      // Store as 'classes' field with JSON Schema content
                      updatedConfig.classes = schemaData;
                    }
                    setFormValues(updatedConfig);
                    setJsonContent(JSON.stringify(updatedConfig, null, 2));
                    try {
                      setYamlContent(yaml.dump(updatedConfig));
                    } catch (e) {
                      console.error('Error converting to YAML:', e);
                    }
                  }
                }}
                onSchemaValidate={(valid, errors) => {
                  if (!valid) {
                    setValidationErrors(errors.map((e) => ({ message: `Schema: ${e.path} - ${e.message}` })));
                  } else {
                    setValidationErrors([]);
                  }
                }}
              />
            )}

            {viewMode === 'json' && (
              <Editor
                height="70vh"
                defaultLanguage="json"
                value={jsonContent}
                onChange={handleJsonEditorChange}
                onMount={handleEditorDidMount}
                options={{
                  minimap: { enabled: false },
                  formatOnPaste: true,
                  formatOnType: true,
                  automaticLayout: true,
                  scrollBeyondLastLine: false,
                  folding: true,
                  lineNumbers: 'on',
                  renderLineHighlight: 'all',
                  tabSize: 2,
                }}
              />
            )}

            {viewMode === 'yaml' && (
              <Box>
                <Editor
                  height="70vh"
                  defaultLanguage="yaml"
                  value={yamlContent}
                  onChange={handleYamlEditorChange}
                  onMount={handleEditorDidMount}
                  options={{
                    minimap: { enabled: false },
                    formatOnPaste: true,
                    formatOnType: true,
                    automaticLayout: true,
                    scrollBeyondLastLine: false,
                    folding: true,
                    lineNumbers: 'on',
                    renderLineHighlight: 'all',
                    tabSize: 2,
                  }}
                />
              </Box>
            )}
          </Box>
        </Form>
      </Container>
    </>
  );
};

export default ConfigurationLayout;
