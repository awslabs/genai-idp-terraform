// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

import React, { useState, useMemo } from 'react';
import {
  Table,
  Box,
  SpaceBetween,
  Link,
  Button,
  Header,
  Pagination,
  TextFilter,
  Alert,
  Badge,
  SegmentedControl,
  CollectionPreferences,
} from '@cloudscape-design/components';
import { useCollection } from '@cloudscape-design/collection-hooks';

interface ConfigVersion {
  versionName: string;
  isActive?: boolean;
  createdAt?: string;
  updatedAt?: string;
  description?: string;
  managed?: boolean;
}

interface ConfigurationVersionsTableProps {
  versions?: ConfigVersion[];
  loading?: boolean;
  onVersionSelect?: (versionName: string) => void;
  selectedVersionsForCompare?: string[];
  currentlyOpenVersion?: string | null;
  onVersionSelectForCompare?: (versionName: string, selected: boolean) => void;
  onCompareVersions?: () => void;
  onActivateVersion?: (versionName: string) => void;
  onDeleteVersions?: (versionNames: string[]) => void;
  onImportAsNewVersion?: () => void;
  isAdmin?: boolean;
}

type TypeFilter = 'all' | 'managed' | 'custom';

const PAGE_SIZE_OPTIONS = [
  { value: 5, label: '5 versions' },
  { value: 10, label: '10 versions' },
  { value: 20, label: '20 versions' },
  { value: 50, label: '50 versions' },
];

const VISIBLE_CONTENT_OPTIONS = [
  { id: 'versionName', label: 'Version Name', editable: false },
  { id: 'type', label: 'Type' },
  { id: 'description', label: 'Description' },
  { id: 'createdAt', label: 'Created' },
  { id: 'updatedAt', label: 'Updated' },
];

const DEFAULT_PREFERENCES = {
  pageSize: 10,
  visibleContent: ['versionName', 'type', 'description', 'createdAt', 'updatedAt'],
  wrapLines: false,
};

const ConfigurationVersionsTable = ({
  versions = [],
  loading = false,
  onVersionSelect,
  selectedVersionsForCompare = [],
  currentlyOpenVersion = null,
  onVersionSelectForCompare,
  onCompareVersions,
  onActivateVersion,
  onDeleteVersions,
  onImportAsNewVersion,
  isAdmin = false,
}: ConfigurationVersionsTableProps): React.JSX.Element => {
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [typeFilter, setTypeFilter] = useState<TypeFilter>('all');
  const [preferences, setPreferences] = useState(DEFAULT_PREFERENCES);

  // Helper: treat both managed flag and 'default' version as managed
  const isVersionManaged = (v: ConfigVersion): boolean => v.managed === true || v.versionName === 'default';

  // Filter versions by type (managed/custom) before passing to useCollection
  const filteredByType = useMemo(() => {
    if (typeFilter === 'all') return versions;
    if (typeFilter === 'managed') return versions.filter((v) => isVersionManaged(v));
    return versions.filter((v) => !isVersionManaged(v));
  }, [versions, typeFilter]);

  // Compute type counts for the segmented control labels
  const managedCount = useMemo(() => versions.filter((v) => isVersionManaged(v)).length, [versions]);
  const customCount = useMemo(() => versions.filter((v) => !isVersionManaged(v)).length, [versions]);

  const allColumnDefinitions = [
    {
      id: 'select',
      header: (
        <input
          type="checkbox"
          checked={selectedVersionsForCompare.length === filteredByType.length && filteredByType.length > 0}
          onChange={(e) => {
            if (e.target.checked) {
              const allVersionNames = filteredByType.map((v) => v.versionName);
              allVersionNames.forEach((versionName) => {
                if (!selectedVersionsForCompare.includes(versionName)) {
                  onVersionSelectForCompare?.(versionName, true);
                }
              });
            } else {
              selectedVersionsForCompare.forEach((versionName) => {
                onVersionSelectForCompare?.(versionName, false);
              });
            }
          }}
          title="Select/Deselect All"
        />
      ),
      cell: (item: ConfigVersion) => (
        <input
          type="checkbox"
          checked={selectedVersionsForCompare.includes(item.versionName)}
          onChange={(e) => onVersionSelectForCompare?.(item.versionName, e.target.checked)}
        />
      ),
      width: 50,
    },
    {
      id: 'versionName',
      header: 'Version Name',
      cell: (item: ConfigVersion) => (
        <Box
          fontWeight={item.versionName === currentlyOpenVersion ? 'bold' : 'normal'}
          color={item.isActive ? 'text-status-success' : item.versionName === currentlyOpenVersion ? 'text-status-info' : 'inherit'}
        >
          <Link
            href="#"
            onFollow={(event) => {
              event.preventDefault();
              onVersionSelect?.(item.versionName);
            }}
          >
            {item.versionName}
          </Link>
        </Box>
      ),
      sortingField: 'versionName',
      width: '25%',
    },
    {
      id: 'type',
      header: 'Type',
      cell: (item: ConfigVersion) => (
        <SpaceBetween direction="horizontal" size="xxs">
          {isVersionManaged(item) ? <Badge color="blue">Managed</Badge> : <Badge color="grey">Custom</Badge>}
          {item.isActive && <Badge color="green">Active</Badge>}
        </SpaceBetween>
      ),
      sortingComparator: (a: ConfigVersion, b: ConfigVersion) => {
        const aType = isVersionManaged(a) ? 'managed' : 'custom';
        const bType = isVersionManaged(b) ? 'managed' : 'custom';
        return aType.localeCompare(bType);
      },
      width: 160,
    },
    {
      id: 'description',
      header: 'Description',
      cell: (item: ConfigVersion) => item.description || '-',
      width: '25%',
    },
    {
      id: 'createdAt',
      header: 'Created',
      cell: (item: ConfigVersion) => (item.createdAt ? new Date(item.createdAt).toLocaleString() : '-'),
      sortingField: 'createdAt',
      width: '20%',
    },
    {
      id: 'updatedAt',
      header: 'Updated',
      cell: (item: ConfigVersion) => (item.updatedAt ? new Date(item.updatedAt).toLocaleString() : '-'),
      sortingField: 'updatedAt',
      width: '20%',
    },
  ];

  // Filter column definitions based on visible content preferences
  // Always include the select column, then only show columns the user has enabled
  const columnDefinitions = allColumnDefinitions.filter((col) => col.id === 'select' || preferences.visibleContent.includes(col.id));

  const { items, collectionProps, paginationProps, filteredItemsCount, filterProps } = useCollection(filteredByType, {
    pagination: { pageSize: preferences.pageSize },
    sorting: {
      defaultState: {
        sortingColumn: allColumnDefinitions.find((col) => col.id === 'updatedAt')!,
        isDescending: true,
      },
    },
    filtering: {
      empty: (
        <Box margin={{ vertical: 'xs' }} textAlign="center" color="inherit">
          <SpaceBetween size="m">
            <b>No matches</b>
            <Box variant="p" color="inherit">
              We can&apos;t find a match.
            </Box>
          </SpaceBetween>
        </Box>
      ),
      noMatch: (
        <Box margin={{ vertical: 'xs' }} textAlign="center" color="inherit">
          <SpaceBetween size="m">
            <b>No matches</b>
            <Box variant="p" color="inherit">
              We can&apos;t find a match.
            </Box>
          </SpaceBetween>
        </Box>
      ),
    },
  });

  return (
    <SpaceBetween size="s">
      {deleteError && (
        <Alert type="error" dismissible onDismiss={() => setDeleteError(null)} header="Cannot Delete Version">
          {deleteError}
        </Alert>
      )}
      <Table
        {...collectionProps}
        columnDefinitions={columnDefinitions}
        items={items}
        loading={loading}
        loadingText="Loading versions..."
        resizableColumns
        stripedRows
        wrapLines={preferences.wrapLines}
        empty={
          <Box margin={{ vertical: 'xs' }} textAlign="center" color="inherit">
            <SpaceBetween size="m">
              <b>No versions</b>
              <Box variant="p" color="inherit">
                No configuration versions found.
              </Box>
            </SpaceBetween>
          </Box>
        }
        header={
          <SpaceBetween size="s">
            <Header {...({ variant: 'h4' } as Record<string, unknown>)}>Configuration Versions ({filteredItemsCount})</Header>
            {/* Action buttons row */}
            <SpaceBetween direction="horizontal" size="xs">
              <Button onClick={onCompareVersions} disabled={selectedVersionsForCompare.length < 2}>
                Compare Selected ({selectedVersionsForCompare.length})
              </Button>
              <Button
                onClick={() => onActivateVersion?.(selectedVersionsForCompare[0])}
                disabled={
                  selectedVersionsForCompare.length !== 1 || versions.find((v) => v.versionName === selectedVersionsForCompare[0])?.isActive
                }
              >
                Activate
              </Button>
              {isAdmin && (
                <Button variant="normal" onClick={() => onImportAsNewVersion?.()} iconName="upload">
                  Import
                </Button>
              )}
              <Button
                variant="primary"
                onClick={() => {
                  // Check if any selected versions are active, default, or managed
                  const activeVersions = selectedVersionsForCompare.filter((vId) => {
                    const version = versions.find((v) => v.versionName === vId);
                    return version?.isActive || vId === 'default';
                  });
                  const managedVersions = selectedVersionsForCompare.filter((vId) => {
                    const version = versions.find((v) => v.versionName === vId);
                    return version?.managed === true;
                  });

                  if (activeVersions.length > 0) {
                    setDeleteError(`Cannot delete active or default versions: ${activeVersions.join(', ')}`);
                    return;
                  }
                  if (managedVersions.length > 0) {
                    setDeleteError(`Cannot delete stack-managed versions: ${managedVersions.join(', ')}`);
                    return;
                  }

                  setDeleteError(null);
                  onDeleteVersions?.(selectedVersionsForCompare);
                }}
                disabled={selectedVersionsForCompare.length === 0}
              >
                Delete Selected ({selectedVersionsForCompare.length})
              </Button>
            </SpaceBetween>
          </SpaceBetween>
        }
        filter={
          <SpaceBetween direction="horizontal" size="m">
            <TextFilter {...filterProps} {...({ placeholder: 'Search versions...' } as Record<string, unknown>)} />
            <SegmentedControl
              selectedId={typeFilter}
              onChange={({ detail }) => setTypeFilter(detail.selectedId as TypeFilter)}
              options={[
                { id: 'all', text: `All (${versions.length})` },
                { id: 'managed', text: `Managed (${managedCount})` },
                { id: 'custom', text: `Custom (${customCount})` },
              ]}
            />
          </SpaceBetween>
        }
        pagination={<Pagination {...paginationProps} />}
        preferences={
          <CollectionPreferences
            title="Preferences"
            confirmLabel="Confirm"
            cancelLabel="Cancel"
            preferences={preferences}
            onConfirm={({ detail }) =>
              setPreferences({
                pageSize: detail.pageSize ?? DEFAULT_PREFERENCES.pageSize,
                visibleContent: (detail.visibleContent as string[]) ?? DEFAULT_PREFERENCES.visibleContent,
                wrapLines: detail.wrapLines ?? DEFAULT_PREFERENCES.wrapLines,
              })
            }
            pageSizePreference={{
              title: 'Page size',
              options: PAGE_SIZE_OPTIONS,
            }}
            visibleContentPreference={{
              title: 'Visible columns',
              options: [
                {
                  label: 'Version properties',
                  options: VISIBLE_CONTENT_OPTIONS,
                },
              ],
            }}
            wrapLinesPreference={{
              label: 'Wrap lines',
              description: 'Select to wrap long text in table cells',
            }}
          />
        }
      />
    </SpaceBetween>
  );
};

export default ConfigurationVersionsTable;
