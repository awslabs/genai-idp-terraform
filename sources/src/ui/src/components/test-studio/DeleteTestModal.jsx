// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import React from 'react';
import PropTypes from 'prop-types';
import { Modal, Box, SpaceBetween, Button } from '@cloudscape-design/components';

const DeleteTestModal = ({ visible, onDismiss, onConfirm, selectedItems, itemType, loading = false }) => {
  const itemCount = selectedItems.length;
  const isMultiple = itemCount > 1;

  const getItemDisplay = (item) => {
    if (itemType === 'test run') {
      return (
        <>
          <strong>{item.testRunId}</strong> ({item.testSetName})
        </>
      );
    }
    if (itemType === 'test set') {
      return (
        <>
          <strong>{item.name}</strong> ({item.filePattern})
        </>
      );
    }
    return <strong>{item.id || item.name || 'Unknown'}</strong>;
  };

  return (
    <Modal
      visible={visible}
      onDismiss={onDismiss}
      header="Confirm Delete"
      footer={
        <Box float="right">
          <SpaceBetween direction="horizontal" size="xs">
            <Button variant="link" onClick={onDismiss}>
              Cancel
            </Button>
            <Button variant="primary" loading={loading} onClick={onConfirm}>
              Delete
            </Button>
          </SpaceBetween>
        </Box>
      }
    >
      <Box>
        <div>
          Are you sure you want to delete the following {itemType}
          {isMultiple ? 's' : ''}?
        </div>
        <ul style={{ marginTop: '10px' }}>
          {selectedItems.map((item) => (
            <li key={item.testRunId || item.id || item.name}>{getItemDisplay(item)}</li>
          ))}
        </ul>
      </Box>
    </Modal>
  );
};

DeleteTestModal.propTypes = {
  visible: PropTypes.bool.isRequired,
  onDismiss: PropTypes.func.isRequired,
  onConfirm: PropTypes.func.isRequired,
  selectedItems: PropTypes.arrayOf(
    PropTypes.shape({
      testRunId: PropTypes.string,
    }),
  ).isRequired,
  itemType: PropTypes.oneOf(['test run', 'test set']).isRequired,
  loading: PropTypes.bool,
};

export default DeleteTestModal;
