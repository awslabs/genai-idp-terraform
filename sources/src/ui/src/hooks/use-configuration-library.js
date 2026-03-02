// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

import { useState } from 'react';
import { generateClient } from 'aws-amplify/api';
import { ConsoleLogger } from 'aws-amplify/utils';

const client = generateClient();
const logger = new ConsoleLogger('useConfigurationLibrary');

const LIST_CONFIG_LIBRARY = `
  query ListConfigurationLibrary($pattern: String!) {
    listConfigurationLibrary(pattern: $pattern) {
      success
      items {
        name
        hasReadme
        path
        configFileType
      }
      error
    }
  }
`;

const GET_CONFIG_LIBRARY_FILE = `
  query GetConfigurationLibraryFile(
    $pattern: String!
    $configName: String!
    $fileName: String!
  ) {
    getConfigurationLibraryFile(
      pattern: $pattern
      configName: $configName
      fileName: $fileName
    ) {
      success
      content
      contentType
      error
    }
  }
`;

const useConfigurationLibrary = () => {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const listConfigurations = async (pattern) => {
    setLoading(true);
    setError(null);

    try {
      logger.debug('Listing configurations for pattern:', pattern);
      const result = await client.graphql({
        query: LIST_CONFIG_LIBRARY,
        variables: { pattern },
      });

      const response = result.data.listConfigurationLibrary;

      if (!response.success) {
        throw new Error(response.error || 'Failed to list configurations');
      }

      logger.debug('Configurations listed successfully:', response.items);
      return response.items || [];
    } catch (err) {
      logger.error('Error listing configurations:', err);
      setError(err.message);
      return [];
    } finally {
      setLoading(false);
    }
  };

  const getFile = async (pattern, configName, fileName) => {
    setLoading(true);
    setError(null);

    try {
      logger.debug('Getting file:', { pattern, configName, fileName });
      const result = await client.graphql({
        query: GET_CONFIG_LIBRARY_FILE,
        variables: { pattern, configName, fileName },
      });

      const response = result.data.getConfigurationLibraryFile;

      if (!response.success) {
        throw new Error(response.error || 'Failed to get file');
      }

      logger.debug('File retrieved successfully');
      return {
        content: response.content,
        contentType: response.contentType,
      };
    } catch (err) {
      logger.error('Error getting file:', err);
      setError(err.message);
      return null;
    } finally {
      setLoading(false);
    }
  };

  return {
    loading,
    error,
    listConfigurations,
    getFile,
  };
};

export default useConfigurationLibrary;
