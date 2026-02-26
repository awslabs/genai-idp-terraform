// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import React from 'react';
import { Link } from '@cloudscape-design/components';

/**
 * Shared function to render HITL (A2I) status consistently across all components
 * @param {Object} item - Document item with HITL fields
 * @returns {string|JSX.Element} - Rendered HITL status
 */
export const renderHitlStatus = (item) => {
  if (!item.hitlTriggered) {
    return 'N/A';
  }

  // Check for failed status first (handle both "Failed" and "FAILED")
  if (item.hitlStatus && (item.hitlStatus.toLowerCase() === 'failed' || item.hitlStatus === 'Failed' || item.hitlStatus === 'FAILED')) {
    return 'A2I Review Failed';
  }

  // Check for completed status
  if (item.hitlCompleted || (item.hitlStatus && item.hitlStatus.toLowerCase() === 'completed')) {
    return 'A2I Review Completed';
  }

  // If we have a review URL, show link
  if (item.hitlReviewURL) {
    return (
      <Link href={item.hitlReviewURL} external>
        A2I Review In Progress
      </Link>
    );
  }

  // If HITL is triggered but no URL, show "In Progress" without link
  return 'A2I Review In Progress';
};

export default renderHitlStatus;
