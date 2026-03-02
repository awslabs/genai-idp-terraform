// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

import React from 'react';
import PropTypes from 'prop-types';
import { Box, Badge } from '@cloudscape-design/components';

/**
 * Enhanced confidence display component with color coding and threshold information
 * @param {Object} props - Component props
 * @param {Object} props.confidenceInfo - Confidence information from getFieldConfidenceInfo
 * @param {string} props.variant - Display variant: 'inline', 'badge', or 'detailed'
 * @param {boolean} props.showThreshold - Whether to show the threshold value
 * @returns {JSX.Element} Confidence display component
 */
const ConfidenceDisplay = ({ confidenceInfo = null, variant = 'detailed', showThreshold = true }) => {
  if (!confidenceInfo || !confidenceInfo.hasConfidenceInfo) {
    return null;
  }

  const { confidence, confidenceThreshold, isAboveThreshold, displayMode } = confidenceInfo;

  // Format confidence as percentage
  const confidencePercent = (confidence * 100).toFixed(1);

  // Determine colors based on threshold comparison
  const getColors = () => {
    if (displayMode === 'with-threshold') {
      return {
        textColor: isAboveThreshold ? '#16794d' : '#d13313', // Green for good, red for poor
        badgeColor: isAboveThreshold ? 'green' : 'red',
        backgroundColor: isAboveThreshold ? '#f0f9f4' : '#fef2f2',
      };
    }
    // No threshold available - use neutral colors
    return {
      textColor: '#000000',
      badgeColor: 'blue',
      backgroundColor: '#f8f9fa',
    };
  };

  const colors = getColors();

  // Format threshold display
  const getThresholdText = () => {
    if (!showThreshold || displayMode !== 'with-threshold' || confidenceThreshold === undefined) {
      return '';
    }
    const thresholdPercent = (confidenceThreshold * 100).toFixed(1);
    return ` (Threshold: ${thresholdPercent}%)`;
  };

  const thresholdText = getThresholdText();

  // Render based on variant
  switch (variant) {
    case 'inline':
      return (
        <span style={{ color: colors.textColor, fontSize: '0.875rem' }}>
          {confidencePercent}%{thresholdText}
        </span>
      );

    case 'badge':
      return (
        <Badge color={colors.badgeColor}>
          {confidencePercent}%{thresholdText}
        </Badge>
      );

    case 'detailed':
    default:
      return (
        <Box
          fontSize="body-s"
          padding={{ top: 'xxxs' }}
          style={{
            color: colors.textColor,
            backgroundColor: colors.backgroundColor,
            padding: '4px 8px',
            borderRadius: '4px',
            display: 'inline-block',
            marginTop: '2px',
          }}
        >
          Confidence: {confidencePercent}%{thresholdText}
        </Box>
      );
  }
};

ConfidenceDisplay.propTypes = {
  confidenceInfo: PropTypes.shape({
    hasConfidenceInfo: PropTypes.bool,
    confidence: PropTypes.number,
    confidenceThreshold: PropTypes.number,
    isAboveThreshold: PropTypes.bool,
    displayMode: PropTypes.string,
  }),
  variant: PropTypes.oneOf(['inline', 'badge', 'detailed']),
  showThreshold: PropTypes.bool,
};

export default ConfidenceDisplay;
