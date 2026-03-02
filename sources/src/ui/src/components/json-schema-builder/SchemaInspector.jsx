import React, { useState, useEffect } from 'react';
import PropTypes from 'prop-types';
import { Box, SpaceBetween, Header, FormField, Input, Select, Textarea, Checkbox, Button, Alert } from '@cloudscape-design/components';
import StringConstraints from './constraints/StringConstraints';
import NumberConstraints from './constraints/NumberConstraints';
import ArrayConstraints from './constraints/ArrayConstraints';
import ObjectConstraints from './constraints/ObjectConstraints';
import MetadataFields from './constraints/MetadataFields';
import ValueConstraints from './constraints/ValueConstraints';
import ExamplesEditor from './constraints/ExamplesEditor';
import {
  TYPE_OPTIONS,
  EVALUATION_METHOD_OPTIONS,
  EVALUATION_THRESHOLD_DEFAULTS,
  EVALUATION_MATCH_THRESHOLD_DEFAULTS,
  METHODS_REQUIRING_THRESHOLD,
  METHODS_REQUIRING_MATCH_THRESHOLD,
  EVALUATION_METHOD_HUNGARIAN,
  X_AWS_IDP_DOCUMENT_TYPE,
  X_AWS_IDP_EVALUATION_METHOD,
  X_AWS_IDP_EVALUATION_THRESHOLD,
  X_AWS_IDP_EVALUATION_WEIGHT,
  X_AWS_IDP_EVALUATION_MATCH_THRESHOLD,
  X_AWS_IDP_CONFIDENCE_THRESHOLD,
  X_AWS_IDP_EXAMPLES,
  X_AWS_IDP_DOCUMENT_NAME_REGEX,
  X_AWS_IDP_PAGE_CONTENT_REGEX,
} from '../../constants/schemaConstants';

const SchemaInspector = ({
  selectedClass,
  selectedAttribute,
  selectedAttributeName,
  onUpdate,
  onUpdateClass,
  onRenameAttribute,
  availableClasses,
  isRequired,
  onToggleRequired,
  onNavigateToClass,
  onNavigateToAttribute,
}) => {
  // Show class-level settings when class is selected but no attribute is selected
  if (selectedClass && (!selectedAttribute || !selectedAttributeName)) {
    // Find where this class is being used
    const usedIn = [];
    if (availableClasses) {
      availableClasses.forEach((cls) => {
        if (cls.id === selectedClass.id) return; // Skip self

        const properties = cls.attributes?.properties || {};
        Object.entries(properties).forEach(([attrName, attrSchema]) => {
          // Check if attribute references this class
          if (attrSchema.$ref === `#/$defs/${selectedClass.name}`) {
            usedIn.push({
              className: cls.name,
              classId: cls.id,
              attributeName: attrName,
              type: 'object',
            });
          } else if (attrSchema.items?.$ref === `#/$defs/${selectedClass.name}`) {
            usedIn.push({
              className: cls.name,
              classId: cls.id,
              attributeName: attrName,
              type: 'array',
            });
          }
        });
      });
    }

    return (
      <Box>
        <Header variant="h3">Class Inspector: {selectedClass.name}</Header>
        <SpaceBetween size="m">
          <FormField label="Document Type" description="Document types become top-level schemas. Shared classes are reusable definitions.">
            <Checkbox
              checked={selectedClass[X_AWS_IDP_DOCUMENT_TYPE] || false}
              onChange={({ detail }) => onUpdateClass({ [X_AWS_IDP_DOCUMENT_TYPE]: detail.checked })}
            >
              This is a document type
            </Checkbox>
          </FormField>

          {selectedClass[X_AWS_IDP_DOCUMENT_TYPE] ? (
            <Alert type="info">
              <strong>Document Type</strong>
              <br />
              This class will be exported as a standalone JSON schema. Each document type schema will only include $defs for classes it
              actually references, keeping schemas minimal and focused.
            </Alert>
          ) : (
            <Alert type="info">
              <strong>Shared Class</strong>
              <br />
              This class is available to be referenced by document types and other classes. It will only appear in the $defs section of
              schemas that reference it.
            </Alert>
          )}

          <FormField label="Class Description" description="Describe the purpose of this class">
            <Textarea
              value={selectedClass.description || ''}
              onChange={({ detail }) => onUpdateClass({ description: detail.value || undefined })}
              rows={3}
              placeholder="Describe what this class represents"
            />
          </FormField>

          {selectedClass[X_AWS_IDP_DOCUMENT_TYPE] && (
            <>
              <ExamplesEditor
                examples={selectedClass[X_AWS_IDP_EXAMPLES] || []}
                onChange={(examples) => onUpdateClass({ [X_AWS_IDP_EXAMPLES]: examples })}
              />

              <FormField
                label="Document Name Regex (Optional)"
                description="Pattern to match document ID/name. When matched, instantly classifies all pages as this type (single-class configs only). Use case-insensitive patterns like (?i).*(invoice|bill).*"
              >
                <Input
                  value={selectedClass[X_AWS_IDP_DOCUMENT_NAME_REGEX] || ''}
                  onChange={({ detail }) => onUpdateClass({ [X_AWS_IDP_DOCUMENT_NAME_REGEX]: detail.value || undefined })}
                  placeholder="e.g., (?i).*(invoice|bill).*"
                />
              </FormField>

              <FormField
                label="Page Content Regex (Optional)"
                description="Pattern to match page text content. When matched during page-level classification, classifies the page as this type. Use case-insensitive patterns like (?i)(invoice\\s+number|amount\\s+due)"
              >
                <Input
                  value={selectedClass[X_AWS_IDP_PAGE_CONTENT_REGEX] || ''}
                  onChange={({ detail }) => onUpdateClass({ [X_AWS_IDP_PAGE_CONTENT_REGEX]: detail.value || undefined })}
                  placeholder="e.g., (?i)(invoice\\s+number|bill\\s+to)"
                />
              </FormField>

              <Header variant="h5">Evaluation Configuration</Header>

              <FormField
                label="Overall Match Threshold"
                description="Minimum weighted score for document-level baseline evaluation match (0-1)"
              >
                <Input
                  type="number"
                  step="0.01"
                  min="0"
                  max="1"
                  value={selectedClass[X_AWS_IDP_EVALUATION_MATCH_THRESHOLD]?.toString() || '0.8'}
                  onChange={({ detail }) => {
                    const value = detail.value ? parseFloat(detail.value) : 0.8;
                    if (value >= 0 && value <= 1) {
                      onUpdateClass({
                        [X_AWS_IDP_EVALUATION_MATCH_THRESHOLD]: value,
                      });
                    }
                  }}
                  placeholder="0.8"
                />
              </FormField>
            </>
          )}

          {usedIn.length > 0 && (
            <FormField
              label="Used In"
              description={`This class is referenced by ${usedIn.length} attribute${usedIn.length > 1 ? 's' : ''}`}
            >
              <SpaceBetween size="xs">
                {usedIn.map((usage) => (
                  <Button
                    key={`${usage.classId}-${usage.attributeName}`}
                    variant="inline-link"
                    iconName="external"
                    onClick={() => {
                      if (onNavigateToAttribute) {
                        onNavigateToAttribute(usage.classId, usage.attributeName);
                      } else if (onNavigateToClass) {
                        onNavigateToClass(usage.classId);
                      }
                    }}
                  >
                    {usage.className}.{usage.attributeName} ({usage.type === 'array' ? `${selectedClass.name}[]` : selectedClass.name})
                  </Button>
                ))}
              </SpaceBetween>
            </FormField>
          )}
        </SpaceBetween>
      </Box>
    );
  }

  if (!selectedAttribute || !selectedAttributeName) {
    return (
      <Box textAlign="center" padding="xxl">
        <Header variant="h3">No Selection</Header>
        <p>Select a class or attribute from the canvas to edit its properties</p>
      </Box>
    );
  }

  const [attributeLabel, setAttributeLabel] = useState(selectedAttributeName || '');

  useEffect(() => {
    setAttributeLabel(selectedAttributeName || '');
  }, [selectedAttributeName]);

  const handleRenameSubmit = () => {
    const trimmed = attributeLabel.trim();
    if (!trimmed || trimmed === selectedAttributeName) {
      setAttributeLabel(selectedAttributeName || '');
      return;
    }

    if (onRenameAttribute && !onRenameAttribute(trimmed)) {
      setAttributeLabel(selectedAttributeName || '');
    }
  };

  return (
    <Box>
      <Header variant="h3">Property Inspector: {selectedAttributeName}</Header>
      <SpaceBetween size="m">
        <FormField label="Attribute Name">
          <Input
            value={attributeLabel}
            onChange={({ detail }) => setAttributeLabel(detail.value)}
            onBlur={handleRenameSubmit}
            onKeyDown={(event) => {
              if (event.key === 'Enter') {
                event.preventDefault();
                handleRenameSubmit();
              }
            }}
          />
        </FormField>

        <Checkbox checked={isRequired} onChange={({ detail }) => onToggleRequired(detail.checked)}>
          Required field
        </Checkbox>

        <FormField label="Type" description="JSON Schema type for this attribute">
          <Select
            selectedOption={
              TYPE_OPTIONS.find((opt) => opt.value === selectedAttribute.type) ||
              // If no type but has $ref, assume it's an object reference
              (selectedAttribute.$ref ? TYPE_OPTIONS.find((opt) => opt.value === 'object') : null) ||
              null
            }
            onChange={({ detail }) => {
              // When changing type, remove $ref if it exists (it's incompatible with inline type)
              const updates = { type: detail.selectedOption.value };
              if (selectedAttribute.$ref) {
                updates.$ref = undefined;
              }
              onUpdate(updates);
            }}
            options={TYPE_OPTIONS}
          />
        </FormField>

        {(selectedAttribute.type === 'object' || selectedAttribute.$ref) && availableClasses && availableClasses.length > 0 && (
          <>
            <FormField
              label="Reference Existing Class (Optional)"
              description="Link to a reusable class definition instead of defining properties inline"
            >
              <SpaceBetween size="xs">
                <Select
                  selectedOption={
                    selectedAttribute.$ref
                      ? {
                          label: selectedAttribute.$ref.replace('#/$defs/', ''),
                          value: selectedAttribute.$ref,
                        }
                      : null
                  }
                  onChange={({ detail }) => {
                    if (detail.selectedOption.value) {
                      const updates = { ...selectedAttribute, $ref: detail.selectedOption.value };
                      // Remove inline object properties as they conflict with $ref
                      delete updates.properties;
                      delete updates.required;
                      delete updates.minProperties;
                      delete updates.maxProperties;
                      delete updates.additionalProperties;
                      // Note: Keep type as 'object' for UI purposes, but it won't be exported in the final schema
                      if (!updates.type) {
                        updates.type = 'object';
                      }
                      onUpdate(updates);
                    } else {
                      const updates = { ...selectedAttribute, $ref: undefined };
                      // Restore type to object when removing $ref
                      if (!updates.type) {
                        updates.type = 'object';
                      }
                      onUpdate(updates);
                    }
                  }}
                  options={[
                    { label: 'None (inline properties)', value: '' },
                    ...availableClasses.map((cls) => ({
                      label: cls.name,
                      value: `#/$defs/${cls.name}`,
                    })),
                  ]}
                  placeholder="Select a class to reference"
                />
                {selectedAttribute.$ref && (onNavigateToClass || onNavigateToAttribute) && (
                  <Button
                    iconName="external"
                    onClick={() => {
                      const className = selectedAttribute.$ref.replace('#/$defs/', '');
                      const referencedClass = availableClasses.find((cls) => cls.name === className);
                      if (referencedClass) {
                        if (onNavigateToAttribute) {
                          onNavigateToAttribute(referencedClass.id, null);
                        } else if (onNavigateToClass) {
                          onNavigateToClass(referencedClass.id);
                        }
                      }
                    }}
                  >
                    Go to {selectedAttribute.$ref.replace('#/$defs/', '')} class
                  </Button>
                )}
              </SpaceBetween>
            </FormField>

            {!selectedAttribute.$ref && <ObjectConstraints attribute={selectedAttribute} onUpdate={onUpdate} />}
          </>
        )}

        {selectedAttribute.type === 'array' && availableClasses && availableClasses.length > 0 && (
          <>
            <FormField label="Array Item Type" description="Define what each item in the array should be">
              <SpaceBetween size="xs">
                <Select
                  selectedOption={
                    selectedAttribute.items?.$ref
                      ? {
                          label: selectedAttribute.items.$ref.replace('#/$defs/', ''),
                          value: selectedAttribute.items.$ref,
                        }
                      : {
                          label: `Simple (${selectedAttribute.items?.type || 'string'})`,
                          value: 'simple',
                        }
                  }
                  onChange={({ detail }) => {
                    if (detail.selectedOption.value === 'simple') {
                      onUpdate({ items: { type: 'string' } });
                    } else {
                      onUpdate({ items: { $ref: detail.selectedOption.value } });
                    }
                  }}
                  options={[
                    { label: 'Simple (string)', value: 'simple' },
                    ...availableClasses.map((cls) => ({
                      label: `Class: ${cls.name}`,
                      value: `#/$defs/${cls.name}`,
                    })),
                  ]}
                />
                {selectedAttribute.items?.$ref && (onNavigateToClass || onNavigateToAttribute) && (
                  <Button
                    iconName="external"
                    onClick={() => {
                      const className = selectedAttribute.items.$ref.replace('#/$defs/', '');
                      const referencedClass = availableClasses.find((cls) => cls.name === className);
                      if (referencedClass) {
                        if (onNavigateToAttribute) {
                          onNavigateToAttribute(referencedClass.id, null);
                        } else if (onNavigateToClass) {
                          onNavigateToClass(referencedClass.id);
                        }
                      }
                    }}
                  >
                    Go to {selectedAttribute.items.$ref.replace('#/$defs/', '')} class
                  </Button>
                )}
              </SpaceBetween>
            </FormField>

            <ArrayConstraints attribute={selectedAttribute} onUpdate={onUpdate} availableClasses={availableClasses} />
          </>
        )}

        <MetadataFields attribute={selectedAttribute} onUpdate={onUpdate} />

        <StringConstraints attribute={selectedAttribute} onUpdate={onUpdate} />

        <NumberConstraints attribute={selectedAttribute} onUpdate={onUpdate} />

        <ValueConstraints attribute={selectedAttribute} onUpdate={onUpdate} />

        <Header variant="h4">Assessment Configuration</Header>

        <FormField
          label="Confidence Threshold"
          description="Minimum confidence score for extraction quality - triggers alert if below this threshold (0-1)"
        >
          <Input
            type="number"
            step="0.01"
            min="0"
            max="1"
            value={selectedAttribute[X_AWS_IDP_CONFIDENCE_THRESHOLD]?.toString() || ''}
            onChange={({ detail }) =>
              onUpdate({
                [X_AWS_IDP_CONFIDENCE_THRESHOLD]: detail.value ? parseFloat(detail.value) : undefined,
              })
            }
            placeholder="e.g., 0.9"
          />
        </FormField>

        <Header variant="h4">Evaluation Configuration (Baseline Accuracy)</Header>

        {(() => {
          // Detect if this is a structured array (List[Object])
          // Must check BOTH inline objects AND $ref to classes (matches backend logic)
          const isStructuredArray =
            selectedAttribute.type === 'array' && (selectedAttribute.items?.type === 'object' || selectedAttribute.items?.$ref);

          // Filter available methods based on field type
          const availableMethods = EVALUATION_METHOD_OPTIONS.filter((opt) => {
            // HUNGARIAN requires structured array
            if (opt.requiresStructuredItems) {
              return isStructuredArray;
            }
            // Methods with validFor restrictions
            if (opt.validFor) {
              // For arrays with SIMPLE items (Array[String], Array[Number], etc.)
              // check if method is valid for the ITEM type
              if (selectedAttribute.type === 'array' && !isStructuredArray) {
                const itemType = selectedAttribute.items?.type || 'string';
                return opt.validFor.includes(itemType);
              }
              // For structured arrays (Array[Object]), check if method is valid for arrays
              if (selectedAttribute.type === 'array' && isStructuredArray) {
                return opt.validFor.includes('array');
              }
              // For other types, check directly
              return opt.validFor.includes(selectedAttribute.type);
            }
            // Default: allow for non-structured-arrays
            return !isStructuredArray;
          });

          const currentMethod = selectedAttribute[X_AWS_IDP_EVALUATION_METHOD];

          return (
            <>
              <FormField label="Evaluation Method" description="Comparison algorithm for baseline accuracy assessment">
                <Select
                  selectedOption={availableMethods.find((opt) => opt.value === currentMethod) || null}
                  onChange={({ detail }) => {
                    const method = detail.selectedOption.value;
                    const updates = {
                      [X_AWS_IDP_EVALUATION_METHOD]: method,
                    };

                    // Auto-set appropriate threshold based on field type
                    if (isStructuredArray) {
                      // For structured arrays, use match_threshold
                      if (EVALUATION_MATCH_THRESHOLD_DEFAULTS[method]) {
                        updates[X_AWS_IDP_EVALUATION_MATCH_THRESHOLD] = EVALUATION_MATCH_THRESHOLD_DEFAULTS[method];
                      }
                      // Clear regular threshold if present
                      updates[X_AWS_IDP_EVALUATION_THRESHOLD] = undefined;
                    } else {
                      // For regular fields, use threshold
                      if (EVALUATION_THRESHOLD_DEFAULTS[method]) {
                        updates[X_AWS_IDP_EVALUATION_THRESHOLD] = EVALUATION_THRESHOLD_DEFAULTS[method];
                      }
                      // Clear match_threshold if present
                      updates[X_AWS_IDP_EVALUATION_MATCH_THRESHOLD] = undefined;
                    }

                    onUpdate(updates);
                  }}
                  options={availableMethods}
                  placeholder="Select evaluation method"
                />
              </FormField>

              {/* Show match-threshold for structured arrays */}
              {isStructuredArray && currentMethod && METHODS_REQUIRING_MATCH_THRESHOLD.includes(currentMethod) && (
                <FormField
                  label="Match Threshold"
                  description="Minimum score for matching items in the array (0-1). Stickler uses Hungarian algorithm to find optimal item pairing."
                >
                  <Input
                    type="number"
                    step="0.01"
                    min="0"
                    max="1"
                    value={selectedAttribute[X_AWS_IDP_EVALUATION_MATCH_THRESHOLD]?.toString() || ''}
                    onChange={({ detail }) =>
                      onUpdate({
                        [X_AWS_IDP_EVALUATION_MATCH_THRESHOLD]: detail.value ? parseFloat(detail.value) : undefined,
                      })
                    }
                    placeholder={`Default: ${EVALUATION_MATCH_THRESHOLD_DEFAULTS[currentMethod] || '0.8'}`}
                  />
                </FormField>
              )}

              {/* Show threshold for non-array fields */}
              {!isStructuredArray && currentMethod && METHODS_REQUIRING_THRESHOLD.includes(currentMethod) && (
                <FormField label="Evaluation Threshold" description="Minimum similarity score to consider a baseline match (0-1)">
                  <Input
                    type="number"
                    step="0.01"
                    min="0"
                    max="1"
                    value={selectedAttribute[X_AWS_IDP_EVALUATION_THRESHOLD]?.toString() || ''}
                    onChange={({ detail }) =>
                      onUpdate({
                        [X_AWS_IDP_EVALUATION_THRESHOLD]: detail.value ? parseFloat(detail.value) : undefined,
                      })
                    }
                    placeholder={`Default: ${EVALUATION_THRESHOLD_DEFAULTS[currentMethod] || ''}`}
                  />
                </FormField>
              )}

              {/* Show weight for non-array fields */}
              {!isStructuredArray && (
                <FormField
                  label="Evaluation Weight"
                  description="Field importance for business criticality (1.0=normal, 2.0=critical, 0.5=optional)"
                >
                  <Input
                    type="number"
                    step="0.1"
                    min="0.1"
                    value={selectedAttribute[X_AWS_IDP_EVALUATION_WEIGHT]?.toString() || '1.0'}
                    onChange={({ detail }) => {
                      const value = detail.value ? parseFloat(detail.value) : 1.0;
                      // Validate minimum
                      if (value >= 0.1) {
                        onUpdate({
                          [X_AWS_IDP_EVALUATION_WEIGHT]: value,
                        });
                      }
                    }}
                    placeholder="1.0"
                  />
                </FormField>
              )}

              {/* Info alert for structured arrays */}
              {isStructuredArray && currentMethod === EVALUATION_METHOD_HUNGARIAN && (
                <Alert type="info">
                  <strong>Hungarian Matching</strong>
                  <br />
                  Stickler uses the Hungarian algorithm to find the optimal pairing between expected and actual list items. The match
                  threshold you set applies to individual item comparisons.
                </Alert>
              )}
            </>
          );
        })()}
      </SpaceBetween>
    </Box>
  );
};

// Memoize the component to prevent re-renders when props haven't changed
export default React.memo(SchemaInspector);

SchemaInspector.propTypes = {
  selectedClass: PropTypes.shape({
    name: PropTypes.string,
    description: PropTypes.string,
    X_AWS_IDP_DOCUMENT_TYPE: PropTypes.bool,
  }),
  selectedAttribute: PropTypes.shape({}),
  selectedAttributeName: PropTypes.string,
  onUpdate: PropTypes.func.isRequired,
  onUpdateClass: PropTypes.func,
  availableClasses: PropTypes.arrayOf(
    PropTypes.shape({
      name: PropTypes.string,
      id: PropTypes.string,
    }),
  ),
  isRequired: PropTypes.bool,
  onToggleRequired: PropTypes.func,
  onRenameAttribute: PropTypes.func,
  onNavigateToClass: PropTypes.func,
  onNavigateToAttribute: PropTypes.func,
};

SchemaInspector.defaultProps = {
  selectedClass: null,
  selectedAttribute: null,
  selectedAttributeName: null,
  availableClasses: [],
  isRequired: false,
  onToggleRequired: () => {},
  onRenameAttribute: () => true,
  onUpdateClass: () => {},
  onNavigateToClass: null,
  onNavigateToAttribute: null,
};
