// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import gql from 'graphql-tag';

export default gql`
  mutation UpdateConfiguration($customConfig: AWSJSON!) {
    updateConfiguration(customConfig: $customConfig) {
      success
      message
      error {
        type
        message
        validationErrors {
          field
          message
          type
        }
      }
    }
  }
`;
