import React, { useState, useMemo } from 'react';
import { Box, SpaceBetween, Input, Checkbox, Button, Badge, ExpandableSection, Alert, Container } from '@cloudscape-design/components';
import standardClassesCatalog from '../../data/standard-classes.json';

interface StandardClassEntry {
  schema: Record<string, unknown>;
  metadata: {
    source: string;
    blueprintName: string;
    description: string;
    attributeCount: number;
    hasListTypes: boolean;
    hasNestedTypes: boolean;
  };
}

interface StandardClassCatalogProps {
  onImport: (schemas: Record<string, unknown>[]) => void;
  existingClassNames: string[];
  onCancel: () => void;
}

const StandardClassCatalog: React.FC<StandardClassCatalogProps> = ({ onImport, existingClassNames, onCancel }) => {
  const [searchText, setSearchText] = useState('');
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());

  const catalogClasses = standardClassesCatalog.classes as StandardClassEntry[];

  const filteredClasses = useMemo(() => {
    if (!searchText.trim()) return catalogClasses;
    const lower = searchText.toLowerCase();
    return catalogClasses.filter(
      (entry) =>
        (entry.schema.$id as string)?.toLowerCase().includes(lower) ||
        entry.metadata.description?.toLowerCase().includes(lower) ||
        entry.metadata.blueprintName?.toLowerCase().includes(lower),
    );
  }, [searchText, catalogClasses]);

  const toggleSelection = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  const handleImport = () => {
    const selectedSchemas = catalogClasses.filter((entry) => selectedIds.has(entry.schema.$id as string)).map((entry) => entry.schema);
    onImport(selectedSchemas);
  };

  const getDuplicateWarning = (classId: string): boolean => {
    return existingClassNames.some((name) => name.toLowerCase() === classId.toLowerCase());
  };

  const formatAttributeSummary = (entry: StandardClassEntry): string => {
    const parts: string[] = [];
    parts.push(`${entry.metadata.attributeCount} attributes`);
    if (entry.metadata.hasListTypes) parts.push('lists');
    if (entry.metadata.hasNestedTypes) parts.push('nested');
    return parts.join(' · ');
  };

  const getPropertyNames = (schema: Record<string, unknown>): string[] => {
    const properties = schema.properties as Record<string, unknown> | undefined;
    return properties ? Object.keys(properties) : [];
  };

  const getPropertyDescription = (schema: Record<string, unknown>, propName: string): string => {
    const properties = schema.properties as Record<string, Record<string, unknown>> | undefined;
    if (!properties || !properties[propName]) return '';
    return (properties[propName].description as string) || '';
  };

  const getPropertyType = (schema: Record<string, unknown>, propName: string): string => {
    const properties = schema.properties as Record<string, Record<string, unknown>> | undefined;
    if (!properties || !properties[propName]) return 'string';
    const prop = properties[propName];
    if (prop.$ref) return 'object ($ref)';
    if (prop.type === 'array') return 'array';
    return (prop.type as string) || 'string';
  };

  return (
    <SpaceBetween size="m">
      <Input
        value={searchText}
        onChange={({ detail }) => setSearchText(detail.value)}
        placeholder="Search standard classes..."
        type="search"
      />

      {filteredClasses.length === 0 && (
        <Box textAlign="center" padding="l" color="text-body-secondary">
          No standard classes match your search.
        </Box>
      )}

      <div
        style={{
          maxHeight: '400px',
          overflowY: 'auto',
          border: '1px solid #e9ebed',
          borderRadius: '8px',
        }}
      >
        <SpaceBetween size="xs">
          {filteredClasses.map((entry) => {
            const classId = entry.schema.$id as string;
            const isSelected = selectedIds.has(classId);
            const isDuplicate = getDuplicateWarning(classId);
            const propNames = getPropertyNames(entry.schema);

            return (
              <div
                key={classId}
                style={{
                  padding: '12px 16px',
                  borderBottom: '1px solid #e9ebed',
                  backgroundColor: isSelected ? '#f2f8fd' : 'transparent',
                  cursor: 'pointer',
                  transition: 'background-color 0.15s ease',
                }}
                role="button"
                tabIndex={0}
                onClick={() => toggleSelection(classId)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    toggleSelection(classId);
                  }
                }}
              >
                <SpaceBetween size="xs">
                  <SpaceBetween direction="horizontal" size="xs" alignItems="center">
                    <span
                      onClick={(e) => e.stopPropagation()}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') {
                          e.stopPropagation();
                        }
                      }}
                      role="button"
                      tabIndex={0}
                    >
                      <Checkbox checked={isSelected} onChange={() => toggleSelection(classId)} />
                    </span>
                    <Box fontWeight="bold" fontSize="body-m">
                      {classId.replace(/-/g, ' ')}
                    </Box>
                    {isDuplicate && <Badge color="red">Duplicate</Badge>}
                    <Box {...({ flex: '1' } as Record<string, unknown>)} />
                    <Box fontSize="body-s" color="text-body-secondary">
                      {formatAttributeSummary(entry)}
                    </Box>
                  </SpaceBetween>

                  {entry.metadata.description && (
                    <Box fontSize="body-s" color="text-body-secondary" padding={{ left: 'xl' }}>
                      {entry.metadata.description}
                    </Box>
                  )}

                  {isDuplicate && (
                    <Box padding={{ left: 'xl' }}>
                      <Alert type="warning" statusIconAriaLabel="Warning">
                        A class with this name already exists. Importing will add a duplicate.
                      </Alert>
                    </Box>
                  )}

                  <div
                    onClick={(e) => e.stopPropagation()}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' || e.key === ' ') {
                        e.stopPropagation();
                      }
                    }}
                    role="button"
                    tabIndex={0}
                    style={{ paddingLeft: '20px' }}
                  >
                    <ExpandableSection headerText="Preview attributes" variant="footer">
                      <Container disableContentPaddings>
                        <div style={{ maxHeight: '200px', overflowY: 'auto' }}>
                          <table
                            style={{
                              width: '100%',
                              borderCollapse: 'collapse',
                              fontSize: '13px',
                            }}
                          >
                            <thead>
                              <tr style={{ borderBottom: '1px solid #e9ebed' }}>
                                <th style={{ textAlign: 'left', padding: '6px 8px', fontWeight: 600 }}>Attribute</th>
                                <th style={{ textAlign: 'left', padding: '6px 8px', fontWeight: 600 }}>Type</th>
                                <th style={{ textAlign: 'left', padding: '6px 8px', fontWeight: 600 }}>Description</th>
                              </tr>
                            </thead>
                            <tbody>
                              {propNames.map((propName) => (
                                <tr key={propName} style={{ borderBottom: '1px solid #f2f3f3' }}>
                                  <td style={{ padding: '4px 8px', fontFamily: 'monospace' }}>{propName}</td>
                                  <td style={{ padding: '4px 8px' }}>
                                    <Badge color={getPropertyType(entry.schema, propName) === 'array' ? 'grey' : 'blue'}>
                                      {getPropertyType(entry.schema, propName)}
                                    </Badge>
                                  </td>
                                  <td style={{ padding: '4px 8px', color: '#5f6b7a' }}>{getPropertyDescription(entry.schema, propName)}</td>
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        </div>
                      </Container>
                    </ExpandableSection>
                  </div>
                </SpaceBetween>
              </div>
            );
          })}
        </SpaceBetween>
      </div>

      <Box fontSize="body-s" color="text-body-secondary">
        <SpaceBetween direction="horizontal" size="xs" alignItems="center">
          <span>ℹ️</span>
          <span>Standard classes use AWS-optimized schemas from BDA standard blueprints. You can customize attributes after import.</span>
        </SpaceBetween>
      </Box>

      <Box float="right">
        <SpaceBetween direction="horizontal" size="xs">
          <Button variant="link" onClick={onCancel}>
            Cancel
          </Button>
          <Button variant="primary" onClick={handleImport} disabled={selectedIds.size === 0}>
            Import Selected ({selectedIds.size})
          </Button>
        </SpaceBetween>
      </Box>
    </SpaceBetween>
  );
};

export default StandardClassCatalog;
