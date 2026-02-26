// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import { getDocumentConfidenceAlertCount } from './confidence-alerts-utils';

// Helper function to determine HITL status without nested ternaries
const getHitlStatus = (status) => {
  if (!status || status === 'N/A') {
    return 'N/A';
  }
  return status;
};

// Helper function to check if HITL is completed
const isHitlCompleted = (status) => {
  if (!status) return false;
  const statusLower = status.toLowerCase();
  return (
    statusLower === 'completed' || statusLower.includes('complete') || statusLower.includes('done') || statusLower.includes('finished')
  );
};

/* Maps document attributes from API to a format that can be used in tables and panel */
// eslint-disable-next-line arrow-body-style
const mapDocumentsAttributes = (documents) => {
  return documents.map((item) => {
    const {
      ObjectKey: objectKey,
      ObjectStatus: objectStatus,
      InitialEventTime: initialEventTime,
      QueuedTime: queuedTime,
      WorkflowStartTime: workflowStartTime,
      CompletionTime: completionTime,
      WorkflowExecutionArn: workflowExecutionArn,
      WorkflowStatus: workflowStatus,
      Sections: sections,
      Pages: pages,
      PageCount: pageCount,
      Metering: meteringJson,
      EvaluationReportUri: evaluationReportUri,
      EvaluationStatus: evaluationStatus,
      SummaryReportUri: summaryReportUri,
      ListPK: listPK,
      ListSK: listSK,
      HITLStatus: hitlStatus,
      HITLReviewURL: hitlReviewURL,
    } = item;

    const formatDate = (timestamp) => {
      return timestamp && timestamp !== '0' ? new Date(timestamp).toISOString() : '';
    };

    const getDuration = (end, start) => {
      if (!end || end === '0' || !start || start === '0') return '';
      const duration = new Date(end) - new Date(start);
      return `${Math.floor(duration / 60000)}:${String(Math.floor((duration / 1000) % 60)).padStart(2, '0')}`;
    };

    // Parse metering data if available
    let metering = null;
    if (meteringJson) {
      try {
        metering = JSON.parse(meteringJson);
      } catch (error) {
        console.error('Error parsing metering data:', error);
      }
    }

    // Calculate confidence alert count
    const confidenceAlertCount = getDocumentConfidenceAlertCount(sections);

    // Extract HITL metadata - use original working logic
    const hitlTriggered = hitlStatus && hitlStatus !== 'N/A';
    const hitlCompleted = isHitlCompleted(hitlStatus);

    // Create a unique ID combining PK and SK for proper row tracking
    const uniqueId = listPK && listSK ? `${listPK}#${listSK}` : objectKey;

    const mapping = {
      uniqueId,
      objectKey,
      objectStatus,
      initialEventTime: formatDate(initialEventTime),
      queuedTime: formatDate(queuedTime),
      workflowStartTime: formatDate(workflowStartTime),
      completionTime: formatDate(completionTime),
      workflowExecutionArn,
      executionArn: workflowExecutionArn, // Add executionArn for Step Functions flow viewer
      workflowStatus,
      duration: getDuration(completionTime, initialEventTime),
      sections,
      pages:
        pages?.map((page) => ({
          ...page,
          TextConfidenceUri: page.TextConfidenceUri || null,
        })) || [],
      pageCount,
      metering,
      evaluationReportUri,
      evaluationStatus,
      summaryReportUri,
      confidenceAlertCount,
      listPK,
      listSK,
      hitlTriggered,
      hitlReviewURL,
      hitlCompleted,
      hitlStatus: getHitlStatus(hitlStatus),
    };

    console.log('mapped-document-attributes', mapping);

    return mapping;
  });
};

export default mapDocumentsAttributes;
