# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import json
import logging
import os
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta
from decimal import Decimal

import boto3

sqs = boto3.client('sqs')


# Custom JSON encoder to handle Decimal objects from DynamoDB
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

dynamodb = boto3.resource('dynamodb')

def handler(event, context):
    """Handle both GraphQL resolver and SQS events"""

    # Check if this is an SQS event
    if 'Records' in event:
        return handle_cache_update_request(event, context)

    # Otherwise handle as GraphQL resolver
    field_name = event['info']['fieldName']

    if field_name == 'getTestRuns':
        time_period_hours = event.get('arguments', {}).get('timePeriodHours', 2)  # Default 2 hours
        logger.info(f"Processing getTestRuns request with timePeriodHours: {time_period_hours}")
        return get_test_runs(time_period_hours)
    elif field_name == 'getTestRun':
        test_run_id = event['arguments']['testRunId']
        logger.info(f"Processing getTestRun request for test run: {test_run_id}")
        return get_test_results(test_run_id)
    elif field_name == 'getTestRunStatus':
        test_run_id = event['arguments']['testRunId']
        logger.info(f"Processing getTestRunStatus request for test run: {test_run_id}")
        return get_test_run_status(test_run_id)
    elif field_name == 'compareTestRuns':
        test_run_ids = event['arguments']['testRunIds']
        logger.info(f"Processing compareTestRuns request for test runs: {test_run_ids}")
        return compare_test_runs(test_run_ids)

    raise ValueError(f"Unknown field: {field_name}")

def handle_cache_update_request(event, context):
    """Process SQS messages to calculate and cache test result metrics"""

    for record in event['Records']:
        try:
            message = json.loads(record['body'])
            test_run_id = message['testRunId']

            logger.info(f"Processing cache update for test run: {test_run_id}")

            # Calculate metrics
            aggregated_metrics = _aggregate_test_run_metrics(test_run_id)

            # Cache the metrics
            metrics_to_cache = {
                'overallAccuracy': aggregated_metrics.get('overall_accuracy'),
                'weightedOverallScores': aggregated_metrics.get('weighted_overall_scores', {}),
                'averageConfidence': aggregated_metrics.get('average_confidence'),
                'accuracyBreakdown': aggregated_metrics.get('accuracy_breakdown', {}),
                'totalCost': aggregated_metrics.get('total_cost', 0),
                'costBreakdown': aggregated_metrics.get('cost_breakdown', {})
            }

            table = dynamodb.Table(os.environ['TRACKING_TABLE'])  # type: ignore[attr-defined]
            table.update_item(
                Key={'PK': f'testrun#{test_run_id}', 'SK': 'metadata'},
                UpdateExpression='SET testRunResult = :metrics',
                ExpressionAttributeValues={':metrics': float_to_decimal(metrics_to_cache)}
            )

            logger.info(f"Successfully cached metrics for test run: {test_run_id}")

        except Exception as e:
            logger.error(f"Failed to process cache update for {record.get('body', 'unknown')}: {e}")
            # Don't raise - let other messages in batch continue processing

def float_to_decimal(obj):
    """Convert float values to Decimal for DynamoDB storage"""
    if isinstance(obj, float):
        return Decimal(str(obj))
    elif isinstance(obj, dict):
        return {k: float_to_decimal(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [float_to_decimal(v) for v in obj]
    return obj

def compare_test_runs(test_run_ids):
    """Compare multiple test runs"""
    logger.info(f"Comparing test runs: {test_run_ids}")

    if not test_run_ids or len(test_run_ids) < 2:
        logger.warning(f"Insufficient test runs for comparison: {len(test_run_ids) if test_run_ids else 0}")
        return {'metrics': [], 'configs': []}

    # Get results for each test run
    results = []
    configs = []

    for test_run_id in test_run_ids:
        logger.info(f"Getting results for test run: {test_run_id}")
        test_result = get_test_results(test_run_id)
        if test_result:
            logger.info(f"Found results for {test_run_id}: {test_result.keys()}")
            results.append(test_result)
            config = _get_test_run_config(test_run_id)
            configs.append({'testRunId': test_run_id, 'config': config})
        else:
            logger.warning(f"No results found for test run: {test_run_id}")

    logger.info(f"Total results found: {len(results)}")

    if len(results) < 2:
        logger.warning(f"Insufficient results for comparison: {len(results)}")
        return {'metrics': [], 'configs': []}

    metrics_comparison = {result['testRunId']: result for result in results}
    configs_comparison = _build_config_comparison(configs)

    logger.info(f"Configs data: {configs}")
    logger.info(f"Config comparison result: {configs_comparison}")

    comparison_result = {
        'metrics': metrics_comparison,
        'configs': configs_comparison
    }

    logger.info(f"Final comparison result: {comparison_result}")

    return comparison_result

def _format_datetime(dt_str):
    """Format datetime string for GraphQL AWSDateTime type"""
    if not dt_str:
        return None
    # Add Z suffix if not present
    return dt_str + 'Z' if not dt_str.endswith('Z') else dt_str

def get_test_results(test_run_id):
    """Get detailed test results for a specific test run"""
    table = dynamodb.Table(os.environ['TRACKING_TABLE'])  # type: ignore[attr-defined]  # type: ignore[attr-defined]

    # Get test run metadata
    response = table.get_item(
        Key={'PK': f'testrun#{test_run_id}', 'SK': 'metadata'}
    )

    if 'Item' not in response:
        raise ValueError(f"Test run {test_run_id} not found")

    metadata = response['Item']
    current_status = metadata.get('Status')

    # Update status if not completed
    if current_status not in ['COMPLETE', 'PARTIAL_COMPLETE']:
        status_result = get_test_run_status(test_run_id)
        if status_result:
            current_status = status_result['status']
            # Refresh metadata after status update
            response = table.get_item(
                Key={'PK': f'testrun#{test_run_id}', 'SK': 'metadata'}
            )
            if 'Item' in response:
                metadata = response['Item']


    # Raise error if status is still not complete
    if current_status not in ['COMPLETE', 'PARTIAL_COMPLETE']:
        raise ValueError(f"Test run {test_run_id} is not complete. Current status: {current_status}")

    # Check if cached results exist
    cached_metrics = metadata.get('testRunResult')
    if cached_metrics is not None:
        logger.info(f"Retrieved cached metrics for test run: {test_run_id}")

        # Check if cached weightedOverallScores is old array format - if so, recalculate
        cached_scores = cached_metrics.get('weightedOverallScores')
        if isinstance(cached_scores, list):
            logger.info(f"Found old array format for weightedOverallScores, recalculating for test run: {test_run_id}")
            # Force recalculation by falling through to aggregation logic
        else:
            # Use cached metrics but get dynamic fields from current metadata
            return {
                'testRunId': test_run_id,
                'testSetId': metadata.get('TestSetId'),
                'testSetName': metadata.get('TestSetName'),
                'status': current_status,
                'filesCount': metadata.get('FilesCount', 0),
                'completedFiles': metadata.get('CompletedFiles', 0),
                'failedFiles': metadata.get('FailedFiles', 0),
                'overallAccuracy': cached_metrics.get('overallAccuracy'),
                'weightedOverallScores': cached_metrics.get('weightedOverallScores', {}),
                'averageConfidence': cached_metrics.get('averageConfidence'),
                'accuracyBreakdown': cached_metrics.get('accuracyBreakdown', {}),
                'totalCost': cached_metrics.get('totalCost', 0),
                'costBreakdown': cached_metrics.get('costBreakdown', {}),
                'createdAt': _format_datetime(metadata.get('CreatedAt')),
                'completedAt': _format_datetime(metadata.get('CompletedAt')),
                'context': metadata.get('Context'),
                'config': _get_test_run_config(test_run_id)
            }

    # Calculate aggregated metrics
    aggregated_metrics = _aggregate_test_run_metrics(test_run_id)

    result = {
        'testRunId': test_run_id,
        'testSetId': metadata.get('TestSetId'),
        'testSetName': metadata.get('TestSetName'),
        'status': current_status,
        'filesCount': metadata.get('FilesCount', 0),
        'completedFiles': metadata.get('CompletedFiles', 0),
        'failedFiles': metadata.get('FailedFiles', 0),
        'overallAccuracy': aggregated_metrics.get('overall_accuracy'),
        'weightedOverallScores': aggregated_metrics.get('weighted_overall_scores', {}),
        'averageConfidence': aggregated_metrics.get('average_confidence'),
        'accuracyBreakdown': aggregated_metrics.get('accuracy_breakdown', {}),
        'totalCost': aggregated_metrics.get('total_cost', 0),
        'costBreakdown': aggregated_metrics.get('cost_breakdown', {}),
        'createdAt': _format_datetime(metadata.get('CreatedAt')),
        'completedAt': _format_datetime(metadata.get('CompletedAt')),
        'context': metadata.get('Context'),
        'config': _get_test_run_config(test_run_id)
    }

    # Cache only the static metrics (not status/counts)
    try:
        logger.info(f"Caching metrics for test run: {test_run_id}")

        # Cache only static metrics
        metrics_to_cache = {
            'overallAccuracy': aggregated_metrics.get('overall_accuracy'),
            'weightedOverallScores': aggregated_metrics.get('weighted_overall_scores', {}),
            'averageConfidence': aggregated_metrics.get('average_confidence'),
            'accuracyBreakdown': aggregated_metrics.get('accuracy_breakdown', {}),
            'totalCost': aggregated_metrics.get('total_cost', 0),
            'costBreakdown': aggregated_metrics.get('cost_breakdown', {})
        }

        table.update_item(
            Key={'PK': f'testrun#{test_run_id}', 'SK': 'metadata'},
            UpdateExpression='SET testRunResult = :testRunResult',
            ExpressionAttributeValues={':testRunResult': float_to_decimal(metrics_to_cache)}
        )
        logger.info(f"Successfully cached metrics for test run: {test_run_id}")
    except Exception as e:
        logger.warning(f"Failed to cache results for {test_run_id}: {e}")

    return result

def get_test_runs(time_period_hours=2):
    """Get list of test runs within specified time period"""
    table = dynamodb.Table(os.environ['TRACKING_TABLE'])  # type: ignore[attr-defined]  # type: ignore[attr-defined]

    # Validate and sanitize time_period_hours
    if time_period_hours is None or not isinstance(time_period_hours, (int, float)):
        time_period_hours = 2  # Default to 2 hours

    # Calculate cutoff time
    cutoff_time = datetime.utcnow() - timedelta(hours=time_period_hours)
    cutoff_iso = cutoff_time.isoformat() + 'Z'

    logger.info(f"Fetching test runs created after: {cutoff_iso}")
    logger.info(f"Current UTC time: {datetime.utcnow().isoformat()}Z")
    logger.info(f"Time period hours: {time_period_hours}")

    # Handle pagination for DynamoDB scan
    items = []
    scan_kwargs = {
        'FilterExpression': 'begins_with(PK, :pk) AND SK = :sk AND CreatedAt >= :cutoff',
        'ExpressionAttributeValues': {
            ':pk': 'testrun#',
            ':sk': 'metadata',
            ':cutoff': cutoff_iso
        }
    }

    while True:
        response = table.scan(**scan_kwargs)
        items.extend(response.get('Items', []))

        if 'LastEvaluatedKey' not in response:
            break
        scan_kwargs['ExclusiveStartKey'] = response['LastEvaluatedKey']

    logger.info(f"DynamoDB scan completed. Items found: {len(items)}")
    if items:
        logger.info(f"Sample item CreatedAt: {items[0].get('CreatedAt')}")
    else:
        logger.info("No items found in scan")

    test_runs = []
    for item in items:
        # If completedAt is missing, call get_test_run_status to update it
        status_result = None
        if not item.get('CompletedAt'):
            status_result = get_test_run_status(item['TestRunId'])
            # Refresh item from database to get updated CompletedAt
            updated_response = table.get_item(
                Key={'PK': f'testrun#{item["TestRunId"]}', 'SK': 'metadata'}
            )
            if 'Item' in updated_response:
                item = updated_response['Item']

        test_runs.append({
            'testRunId': item['TestRunId'],
            'testSetId': item.get('TestSetId'),
            'testSetName': item.get('TestSetName'),
            'status': status_result.get('status') if status_result else item.get('Status'),
            'filesCount': item.get('FilesCount', 0),
            'completedFiles': status_result.get('completedFiles') if status_result else item.get('CompletedFiles', 0),
            'failedFiles': status_result.get('failedFiles') if status_result else item.get('FailedFiles', 0),
            'createdAt': _format_datetime(item.get('CreatedAt')),
            'completedAt': _format_datetime(item.get('CompletedAt')),
            'context': item.get('Context')
        })

    # Sort by createdAt descending (most recent first)
    # Handle None values and convert to datetime for proper sorting
    def sort_key(test_run):
        created_at = test_run.get('createdAt')
        if not created_at:
            return '1970-01-01T00:00:00Z'  # Very old date for None values
        return created_at

    test_runs.sort(key=sort_key, reverse=True)

    return test_runs

def _calculate_completed_at(test_run_id, files, table):
    """Calculate completedAt timestamp from document CompletionTime"""
    latest_completion_time = None

    for file_key in files:
        doc_response = table.get_item(
            Key={'PK': f'doc#{test_run_id}/{file_key}', 'SK': 'none'}
        )
        if 'Item' in doc_response:
            doc_item = doc_response['Item']
            completion_time = doc_item.get('CompletionTime')
            if completion_time:
                completion_time = completion_time.replace('+00:00', 'Z')
                if not latest_completion_time or completion_time > latest_completion_time:
                    latest_completion_time = completion_time

    return latest_completion_time

def get_test_run_status(test_run_id):
    """Get lightweight status for specific test run - checks both document and evaluation status"""
    table = dynamodb.Table(os.environ['TRACKING_TABLE'])  # type: ignore[attr-defined]

    try:
        logger.info(f"Getting test run status for: {test_run_id}")

        # Get test run metadata
        response = table.get_item(
            Key={'PK': f'testrun#{test_run_id}', 'SK': 'metadata'}
        )

        if 'Item' not in response:
            logger.warning(f"Test run metadata not found for: {test_run_id}")
            return None

        item = response['Item']
        files = item.get('Files', [])
        files_count = item.get('FilesCount', 0)
        logger.info(f"Test run {test_run_id}: Found {files_count} files")

        # Always check actual document status from tracking table
        completed_files = 0
        processing_failed_files = 0  # Only count processing failures found during scan
        evaluating_files = 0
        queued_files = 0

        for file_key in files:
            logger.info(f"Checking file: {file_key} for test run: {test_run_id}")
            doc_response = table.get_item(
                Key={'PK': f'doc#{test_run_id}/{file_key}', 'SK': 'none'}
            )
            if 'Item' in doc_response:
                doc_status = doc_response['Item'].get('ObjectStatus', 'QUEUED')
                eval_status = doc_response['Item'].get('EvaluationStatus')
                logger.info(f"File {file_key}: ObjectStatus={doc_status}, EvaluationStatus={eval_status}")

                if doc_status == 'COMPLETED':
                    # Check if evaluation is also complete
                    if eval_status == 'COMPLETED':
                        completed_files += 1
                        logger.info(f"File {file_key}: counted as completed")
                    elif eval_status == 'RUNNING':
                        evaluating_files += 1
                        logger.info(f"File {file_key}: counted as evaluating")
                    elif eval_status is None:
                        # Document completed but evaluation not started yet
                        evaluating_files += 1
                        logger.info(f"File {file_key}: counted as evaluating (eval not started)")
                    elif eval_status == 'FAILED':
                        # Evaluation failed - count as failed
                        processing_failed_files += 1
                        logger.info(f"File {file_key}: counted as failed (eval failed)")
                    elif eval_status == 'NO_BASELINE':
                        # No baseline data available - count as completed
                        completed_files += 1
                        logger.info(f"File {file_key}: counted as completed (no baseline data)")
                    else:
                        # Unknown evaluation status - count as evaluating
                        evaluating_files += 1
                        logger.info(f"File {file_key}: counted as evaluating (unknown eval status: {eval_status})")
                elif doc_status == 'FAILED':
                    processing_failed_files += 1
                    logger.info(f"File {file_key}: counted as failed")
                elif doc_status == 'QUEUED':
                    queued_files += 1
                    logger.info(f"File {file_key}: counted as queued")
                else:
                    logger.info(f"File {file_key}: still processing (status: {doc_status})")
            else:
                logger.warning(f"Document not found: doc#{test_run_id}/{file_key}")
                # Count missing documents as queued (not yet created)
                queued_files += 1

        # Calculate total failed files
        baseline_failed_files = item.get('BaselineFailedFiles', 0)  # Set by copier, never updated
        total_failed_files = baseline_failed_files + processing_failed_files  # Recalculated each call

        logger.info(f"Test run {test_run_id} counts: completed={completed_files}, processing_failed={processing_failed_files}, baseline_failed={baseline_failed_files}, total_failed={total_failed_files}, evaluating={evaluating_files}, queued={queued_files}, total={files_count}")

        # Determine overall test run status based on document and evaluation states
        if completed_files == files_count and files_count > 0 and total_failed_files == 0:
            overall_status = 'COMPLETE'
        elif total_failed_files > 0 and (completed_files + total_failed_files + evaluating_files) == files_count:
            overall_status = 'PARTIAL_COMPLETE'
        elif evaluating_files > 0:
            overall_status = 'EVALUATING'
        elif queued_files == files_count:
            overall_status = 'QUEUED'  # All files are still queued
        elif completed_files + total_failed_files + evaluating_files + queued_files < files_count:
            overall_status = 'RUNNING'  # Some files are actively processing
        else:
            overall_status = item.get('Status', 'RUNNING')

        # Auto-update database metadata if calculated status differs from stored status
        stored_status = item.get('Status', 'RUNNING')
        if overall_status != stored_status:
            # Calculate completedAt from document completion times if status is complete
            calculated_completed_at = item.get('CompletedAt')
            if overall_status in ['COMPLETE', 'PARTIAL_COMPLETE'] and not calculated_completed_at:
                calculated_completed_at = _calculate_completed_at(test_run_id, files, table)

            logger.info(f"Auto-updating test run {test_run_id} status from {stored_status} to {overall_status}")
            try:
                table.update_item(
                    Key={'PK': f'testrun#{test_run_id}', 'SK': 'metadata'},
                    UpdateExpression='SET #status = :status, #completedAt = :completedAt, CompletedFiles = :completedFiles, FailedFiles = :failedFiles',
                    ExpressionAttributeNames={'#status': 'Status', '#completedAt': 'CompletedAt'},
                    ExpressionAttributeValues={
                        ':status': overall_status,
                        ':completedAt': calculated_completed_at,
                        ':completedFiles': completed_files,
                        ':failedFiles': total_failed_files
                    }
                )
                logger.info(f"Successfully updated test run {test_run_id} status to {overall_status}")

                # Queue metric calculation for completed test runs
                if overall_status in ['COMPLETE', 'PARTIAL_COMPLETE'] and not item.get('testRunResult'):
                    try:
                        queue_url = os.environ.get('TEST_RESULT_CACHE_UPDATE_QUEUE_URL')
                        if queue_url:
                            sqs.send_message(
                                QueueUrl=queue_url,
                                MessageBody=json.dumps({'testRunId': test_run_id})
                            )
                            logger.info(f"Queued cache update for test run: {test_run_id}")
                    except Exception as e:
                        logger.warning(f"Failed to queue cache update for {test_run_id}: {e}")

            except Exception as e:
                logger.error(f"Failed to auto-update test run {test_run_id} status: {e}")

        progress = ((completed_files + total_failed_files) / files_count * 100) if files_count > 0 else 0

        result = {
            'testRunId': test_run_id,
            'status': overall_status,
            'filesCount': files_count,
            'completedFiles': completed_files,
            'failedFiles': total_failed_files,
            'evaluatingFiles': evaluating_files,
            'progress': progress
        }

        logger.info(f"Test run {test_run_id} final result: {result}")
        return result

    except Exception as e:
        logger.error(f"Error getting test run status for {test_run_id}: {e}")
        return None

def _parse_s3_uri(uri):
    """Parse S3 URI into bucket and key"""
    if uri and uri.startswith('s3://'):
        parts = uri[5:].split('/', 1)
        if len(parts) == 2:
            return parts[0], parts[1]
    return None, None

def _aggregate_test_run_metrics(test_run_id):
    """Aggregate metrics from evaluation reports for all documents in test run"""
    table = dynamodb.Table(os.environ['TRACKING_TABLE'])  # type: ignore[attr-defined]

    # Get all documents for this test run that completed successfully
    items = []
    scan_kwargs = {
        'FilterExpression': 'begins_with(PK, :pk) AND SK = :sk AND ObjectStatus = :status',
        'ExpressionAttributeValues': {
            ':pk': f'doc#{test_run_id}/',
            ':sk': 'none',
            ':status': 'COMPLETED'
        }
    }

    while True:
        response = table.scan(**scan_kwargs)
        items.extend(response.get('Items', []))
        if 'LastEvaluatedKey' not in response:
            break
        scan_kwargs['ExclusiveStartKey'] = response['LastEvaluatedKey']

    if not items:
        return {}

    # Aggregate metrics from evaluation reports
    total_accuracy = 0
    total_confidence = 0
    total_cost = 0
    accuracy_count = 0
    confidence_count = 0
    weighted_overall_scores = {}  # Dict to collect document ID -> score mapping
    cost_breakdown = {}

    # Accuracy metrics aggregation
    total_precision = 0
    total_recall = 0
    total_f1_score = 0
    total_false_alarm_rate = 0
    total_false_discovery_rate = 0
    precision_count = 0
    recall_count = 0
    f1_count = 0
    far_count = 0
    fdr_count = 0

    s3 = boto3.client('s3')

    for item in items:
        evaluation_uri = item.get('EvaluationReportUri')
        if not evaluation_uri:
            continue

        try:
            # Get evaluation report data
            json_uri = evaluation_uri.replace('report.md', 'results.json')
            bucket, key = _parse_s3_uri(json_uri)
            if bucket and key:
                obj = s3.get_object(Bucket=bucket, Key=key)
                data = json.loads(obj['Body'].read())

                # Extract accuracy from overall_metrics
                overall_metrics = data.get('overall_metrics', {})
                if overall_metrics.get('accuracy'):
                    total_accuracy += overall_metrics['accuracy']
                    accuracy_count += 1

                # Extract weighted overall score
                if overall_metrics.get('weighted_overall_score') is not None:
                    # Extract document ID from the item PK (format: doc#{test_run_id}/{file_key})
                    document_id = item['PK'].replace('doc#', '', 1)
                    weighted_overall_scores[document_id] = overall_metrics['weighted_overall_score']

                # Extract additional accuracy metrics
                if overall_metrics.get('precision'):
                    total_precision += overall_metrics['precision']
                    precision_count += 1
                if overall_metrics.get('recall'):
                    total_recall += overall_metrics['recall']
                    recall_count += 1
                if overall_metrics.get('f1_score'):
                    total_f1_score += overall_metrics['f1_score']
                    f1_count += 1
                if overall_metrics.get('false_alarm_rate'):
                    total_false_alarm_rate += overall_metrics['false_alarm_rate']
                    far_count += 1
                if overall_metrics.get('false_discovery_rate'):
                    total_false_discovery_rate += overall_metrics['false_discovery_rate']
                    fdr_count += 1

                # Extract confidence from section results
                confidences = []
                for section in data.get('section_results', []):
                    for attr in section.get('attributes', []):
                        if attr.get('confidence') is not None:
                            confidences.append(float(attr['confidence']))

                if confidences:
                    avg_confidence = sum(confidences) / len(confidences)
                    total_confidence += avg_confidence
                    confidence_count += 1

        except Exception as e:
            logger.warning(f"Failed to process evaluation report for {item['PK']}: {e}")
            continue

        # Get cost from completion date if available
        if item.get('CompletionTime'):
            completion_date = datetime.fromisoformat(item['CompletionTime']).strftime('%Y-%m-%d')
            doc_key = item['PK'].replace('doc#', '')
            doc_costs = _get_document_costs_from_reporting_db(doc_key, completion_date)

            for context, services in doc_costs.items():
                if context not in cost_breakdown:
                    cost_breakdown[context] = {}

                for service_unit, details in services.items():
                    if service_unit not in cost_breakdown[context]:
                        cost_breakdown[context][service_unit] = {
                            'unit': details['unit'],
                            'value': 0,
                            'unit_cost': details['unit_cost'],
                            'estimated_cost': 0
                        }

                    cost_breakdown[context][service_unit]['value'] += details['value']
                    cost_breakdown[context][service_unit]['estimated_cost'] += details['estimated_cost']
                    total_cost += details['estimated_cost']

    return {
        'overall_accuracy': total_accuracy / accuracy_count if accuracy_count > 0 else None,
        'weighted_overall_scores': weighted_overall_scores if weighted_overall_scores else {},
        'average_confidence': total_confidence / confidence_count if confidence_count > 0 else None,
        'accuracy_breakdown': {
            'precision': total_precision / precision_count if precision_count > 0 else None,
            'recall': total_recall / recall_count if recall_count > 0 else None,
            'f1_score': total_f1_score / f1_count if f1_count > 0 else None,
            'false_alarm_rate': total_false_alarm_rate / far_count if far_count > 0 else None,
            'false_discovery_rate': total_false_discovery_rate / fdr_count if fdr_count > 0 else None
        },
        'total_cost': total_cost,
        'cost_breakdown': cost_breakdown
    }



def _get_document_costs_from_reporting_db(document_id, completion_date):
    """Get detailed costs from S3 Parquet files using provided completion date"""
    try:
        import pyarrow.compute as pc
        import pyarrow.fs as fs
        import pyarrow.parquet as pq

        # Get reporting bucket from environment
        reporting_bucket = os.environ.get('REPORTING_BUCKET')
        if not reporting_bucket:
            return {}

        logger.info(f"Using completion date {completion_date} for document {document_id}")

        # List files in the specific date partition
        s3 = boto3.client('s3')
        partition_prefix = f"metering/date={completion_date}/"

        response = s3.list_objects_v2(Bucket=reporting_bucket, Prefix=partition_prefix)

        if 'Contents' not in response:
            logger.warning(f"No files found in partition {completion_date}")
            return {}

        # Find the parquet file for this document
        document_pattern = document_id.replace('/', '_')

        for obj in response['Contents']:
            if obj['Key'].endswith('_results.parquet') and document_pattern in obj['Key']:
                logger.info(f"Reading parquet file: {obj['Key']}")

                # Read parquet file using pyarrow
                s3_fs = fs.S3FileSystem()
                parquet_file = f"{reporting_bucket}/{obj['Key']}"

                table_data = pq.read_table(parquet_file, filesystem=s3_fs)

                # Filter by document_id if column exists
                if 'document_id' in table_data.column_names:
                    mask = pc.equal(table_data['document_id'], document_id)  # type: ignore
                    table_data = table_data.filter(mask)

                if table_data.num_rows == 0:
                    return {}

                # Convert to Python dict for processing
                data = table_data.to_pydict()

                # Group detailed cost information
                cost_details = {}
                for i in range(len(data['context'])):
                    context = data['context'][i]
                    service_api = data['service_api'][i]
                    unit = data['unit'][i]
                    value = float(data['value'][i])
                    unit_cost = float(data['unit_cost'][i])
                    estimated_cost = float(data['estimated_cost'][i])

                    if context not in cost_details:
                        cost_details[context] = {}

                    key = f"{service_api}_{unit}"
                    if key not in cost_details[context]:
                        cost_details[context][key] = {
                            'unit': unit,
                            'value': 0,
                            'unit_cost': unit_cost,
                            'estimated_cost': 0
                        }

                    cost_details[context][key]['value'] += value
                    cost_details[context][key]['estimated_cost'] += estimated_cost

                return cost_details

        logger.warning(f"No parquet file found for {document_id} in {completion_date}")
        return {}

    except Exception as e:
        logger.warning(f"Failed to get costs from parquet for {document_id}: {e}")
        return {}


def _get_test_run_config(test_run_id):
    """Get test run configuration from metadata record"""
    table = dynamodb.Table(os.environ['TRACKING_TABLE'])  # type: ignore[attr-defined]
    response = table.get_item(
        Key={'PK': f'testrun#{test_run_id}', 'SK': 'metadata'}
    )

    config = response.get('Item', {}).get('Config', {})

    # Convert DynamoDB Decimal objects to regular Python types for JSON serialization
    def convert_decimals(obj):
        if isinstance(obj, dict):
            return {k: convert_decimals(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [convert_decimals(v) for v in obj]
        elif hasattr(obj, '__class__') and obj.__class__.__name__ == 'Decimal':
            # Convert Decimal to float or int
            if obj % 1 == 0:
                return int(obj)
            else:
                return float(obj)
        else:
            return obj

    return convert_decimals(config)

def _build_config_comparison(configs):
    """Build configuration differences - compare Custom configs, fallback to Default"""
    if not configs or len(configs) < 2:
        return None

    def get_nested_value(dictionary, path):
        """Get nested value from dictionary using dot notation path"""
        keys = path.split('.')
        current = dictionary
        for key in keys:
            if isinstance(current, dict) and key in current:
                current = current[key]
            else:
                return None
        return current

    def get_all_paths(dictionary, prefix=""):
        """Get all nested paths from dictionary"""
        paths = []
        for key, value in dictionary.items():
            current_path = f"{prefix}.{key}" if prefix else key
            if isinstance(value, dict):
                paths.extend(get_all_paths(value, current_path))
            else:
                paths.append(current_path)
        return paths

    # Get all possible configuration paths from all configs
    all_paths = set()
    default_config = {}

    for config_item in configs:
        config = config_item['config']
        custom = config.get('Custom', {})
        default = config.get('Default', {})

        all_paths.update(get_all_paths(custom))
        all_paths.update(get_all_paths(default))

        # Use first config's default as reference
        if not default_config:
            default_config = default

    differences = []
    for path in all_paths:
        values = {}
        has_differences = False
        first_value = None

        # Get effective values for each test run
        for config_item in configs:
            test_run_id = config_item['testRunId']
            config = config_item['config']
            custom = config.get('Custom', {})
            default = config.get('Default', {})

            # Get effective value (Custom overrides Default)
            value = get_nested_value(custom, path)
            if value is None:
                value = get_nested_value(default, path)

            if value is not None:
                # Normalize the value for comparison
                if isinstance(value, str):
                    # Strip whitespace and normalize string values
                    str_value = value.strip()
                else:
                    str_value = str(value).strip()

                values[test_run_id] = str_value

                # Check for differences using normalized values
                if first_value is None:
                    first_value = str_value
                elif first_value != str_value:
                    has_differences = True

        # Only include if there are differences and at least 2 values
        if has_differences and len(values) >= 2:
            differences.append({
                'setting': path,
                'values': values
            })

    return differences
