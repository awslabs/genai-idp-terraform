// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0
import React, { useState } from 'react';
import PropTypes from 'prop-types';
import { Table, Box, Container, Header, Pagination, CollectionPreferences } from '@cloudscape-design/components';

const TableDisplay = ({ tableData = null }) => {
  const [preferences, setPreferences] = useState({
    pageSize: 10,
    visibleContent: ['all'],
  });
  const [currentPageIndex, setCurrentPageIndex] = useState(1);

  if (!tableData) {
    return null;
  }

  const { headers, rows } = tableData;

  // Convert headers to AWS UI table format
  const columnDefinitions = headers.map((header) => ({
    id: header.id,
    header: header.label,
    cell: (item) => item.data[header.id],
    sortingField: header.sortable ? header.id : undefined,
  }));

  // Paginate the data
  const startIndex = (currentPageIndex - 1) * preferences.pageSize;
  const endIndex = startIndex + preferences.pageSize;
  const paginatedItems = rows.slice(startIndex, endIndex);

  return (
    <Container header={<Header variant="h3">Table Results</Header>}>
      <Table
        columnDefinitions={columnDefinitions}
        items={paginatedItems}
        loadingText="Loading table data"
        sortingDisabled={false}
        empty={
          <Box textAlign="center" color="inherit">
            <b>No data available</b>
            <Box padding={{ bottom: 's' }} variant="p" color="inherit">
              No table data to display.
            </Box>
          </Box>
        }
        pagination={
          <Pagination
            currentPageIndex={currentPageIndex}
            onChange={({ detail }) => setCurrentPageIndex(detail.currentPageIndex)}
            pagesCount={Math.ceil(rows.length / preferences.pageSize)}
          />
        }
        preferences={
          <CollectionPreferences
            title="Preferences"
            confirmLabel="Confirm"
            cancelLabel="Cancel"
            preferences={preferences}
            onConfirm={({ detail }) => setPreferences(detail)}
            pageSizePreference={{
              title: 'Page size',
              options: [
                { value: 5, label: '5 rows' },
                { value: 10, label: '10 rows' },
                { value: 20, label: '20 rows' },
                { value: 50, label: '50 rows' },
              ],
            }}
            visibleContentPreference={{
              title: 'Select visible content',
              options: [
                {
                  label: 'Main table properties',
                  options: columnDefinitions.map(({ id, header }) => ({
                    id,
                    label: header,
                  })),
                },
              ],
            }}
          />
        }
      />
    </Container>
  );
};

TableDisplay.propTypes = {
  tableData: PropTypes.shape({
    headers: PropTypes.arrayOf(
      PropTypes.shape({
        id: PropTypes.string.isRequired,
        label: PropTypes.string.isRequired,
        sortable: PropTypes.bool,
      }),
    ),
    rows: PropTypes.arrayOf(
      PropTypes.shape({
        id: PropTypes.string.isRequired,
        data: PropTypes.shape({
          processing_date: PropTypes.string,
          documents_processed: PropTypes.number,
        }).isRequired,
      }),
    ),
  }),
};

export default TableDisplay;
