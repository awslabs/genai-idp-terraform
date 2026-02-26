// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0
import React, { createContext, useContext, useState, useCallback, useMemo } from 'react';
import PropTypes from 'prop-types';

const AnalyticsContext = createContext(null);

export const AnalyticsProvider = ({ children }) => {
  // State for the analytics page
  const [analyticsState, setAnalyticsState] = useState({
    queryText: '', // The submitted/executed query
    currentInputText: '', // The current text in the input box
    jobId: null,
    jobStatus: null,
    jobResult: null,
    agentMessages: null,
    error: null,
    isSubmitting: false,
    subscription: null,
  });

  // Function to update analytics state
  const updateAnalyticsState = useCallback((updates) => {
    setAnalyticsState((prevState) => ({
      ...prevState,
      ...updates,
    }));
  }, []);

  // Function to reset analytics state
  const resetAnalyticsState = useCallback(() => {
    setAnalyticsState({
      queryText: '',
      currentInputText: '',
      jobId: null,
      jobStatus: null,
      jobResult: null,
      agentMessages: null,
      error: null,
      isSubmitting: false,
      subscription: null,
    });
  }, []);

  // Function to clear only results but keep query
  const clearAnalyticsResults = useCallback(() => {
    setAnalyticsState((prevState) => ({
      ...prevState,
      jobId: null,
      jobStatus: null,
      jobResult: null,
      agentMessages: null,
      error: null,
      isSubmitting: false,
      subscription: null,
    }));
  }, []);

  const contextValue = useMemo(
    () => ({
      analyticsState,
      updateAnalyticsState,
      resetAnalyticsState,
      clearAnalyticsResults,
    }),
    [analyticsState, updateAnalyticsState, resetAnalyticsState, clearAnalyticsResults],
  );

  return <AnalyticsContext.Provider value={contextValue}>{children}</AnalyticsContext.Provider>;
};

AnalyticsProvider.propTypes = {
  children: PropTypes.node.isRequired,
};

export const useAnalyticsContext = () => {
  const context = useContext(AnalyticsContext);
  if (!context) {
    throw new Error('useAnalyticsContext must be used within an AnalyticsProvider');
  }
  return context;
};

export default AnalyticsContext;
