// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0
import React, { useState, useEffect } from 'react';
import PropTypes from 'prop-types';
import { Box, Container, Header, Select, SpaceBetween } from '@cloudscape-design/components';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  LineElement,
  PointElement,
  Title,
  Tooltip,
  Legend,
  ArcElement,
  Filler,
} from 'chart.js';
import { Bar, Line, Pie, Doughnut } from 'react-chartjs-2';

// Register Chart.js components
ChartJS.register(CategoryScale, LinearScale, BarElement, LineElement, PointElement, Title, Tooltip, Legend, ArcElement, Filler);

const PlotDisplay = ({ plotData = null }) => {
  // Chart type options for the dropdown
  const chartTypeOptions = [
    { label: 'Bar Chart', value: 'bar' },
    { label: 'Line Chart', value: 'line' },
    { label: 'Pie Chart', value: 'pie' },
    { label: 'Doughnut Chart', value: 'doughnut' },
  ];

  // State to track the current chart type, initialized with the type from JSON
  const [currentChartType, setCurrentChartType] = useState(null);
  const [selectedOption, setSelectedOption] = useState(null);

  // Initialize chart type when plotData changes
  useEffect(() => {
    if (plotData?.type) {
      const initialType = plotData.type.toLowerCase();
      setCurrentChartType(initialType);

      // Find the matching option for the Select component
      const matchingOption = chartTypeOptions.find((option) => option.value === initialType);
      setSelectedOption(matchingOption || chartTypeOptions[0]);
    }
  }, [plotData]);

  if (!plotData) {
    return null;
  }

  // Handle chart type change from dropdown
  const handleChartTypeChange = ({ detail }) => {
    setCurrentChartType(detail.selectedOption.value);
    setSelectedOption(detail.selectedOption);
  };

  // Prepare chart data with potential modifications for different chart types
  const prepareChartData = (originalData, chartType) => {
    const { datasets, labels } = originalData;

    // Ensure labels are strings to avoid PropTypes warnings
    const stringLabels = labels ? labels.map((label) => String(label)) : [];

    // For pie and doughnut charts, we might need to aggregate data if there are multiple datasets
    if ((chartType === 'pie' || chartType === 'doughnut') && datasets.length > 1) {
      // Aggregate all datasets into a single dataset for pie/doughnut charts
      const aggregatedData = stringLabels.map((_, index) => datasets.reduce((sum, dataset) => sum + (dataset.data[index] || 0), 0));

      return {
        labels: stringLabels,
        datasets: [
          {
            data: aggregatedData,
            backgroundColor: [
              'rgba(255, 99, 132, 0.8)',
              'rgba(54, 162, 235, 0.8)',
              'rgba(255, 205, 86, 0.8)',
              'rgba(75, 192, 192, 0.8)',
              'rgba(153, 102, 255, 0.8)',
              'rgba(255, 159, 64, 0.8)',
              'rgba(255, 193, 7, 0.8)',
              'rgba(76, 175, 80, 0.8)',
              'rgba(156, 39, 176, 0.8)',
              'rgba(96, 125, 139, 0.8)',
            ],
            borderColor: [
              'rgba(255, 99, 132, 1)',
              'rgba(54, 162, 235, 1)',
              'rgba(255, 205, 86, 1)',
              'rgba(75, 192, 192, 1)',
              'rgba(153, 102, 255, 1)',
              'rgba(255, 159, 64, 1)',
              'rgba(255, 193, 7, 1)',
              'rgba(76, 175, 80, 1)',
              'rgba(156, 39, 176, 1)',
              'rgba(96, 125, 139, 1)',
            ],
            borderWidth: 1,
            label: datasets.map((d) => d.label).join(' + ') || 'Combined Data',
          },
        ],
      };
    }

    // For pie and doughnut charts with single dataset, ensure proper color arrays
    if ((chartType === 'pie' || chartType === 'doughnut') && datasets.length === 1) {
      const dataset = datasets[0];
      const dataLength = dataset.data.length;

      // Generate colors if not provided or if there aren't enough colors
      const defaultColors = [
        'rgba(255, 99, 132, 0.8)',
        'rgba(54, 162, 235, 0.8)',
        'rgba(255, 205, 86, 0.8)',
        'rgba(75, 192, 192, 0.8)',
        'rgba(153, 102, 255, 0.8)',
        'rgba(255, 159, 64, 0.8)',
        'rgba(255, 193, 7, 0.8)',
        'rgba(76, 175, 80, 0.8)',
        'rgba(156, 39, 176, 0.8)',
        'rgba(96, 125, 139, 0.8)',
      ];

      const defaultBorderColors = [
        'rgba(255, 99, 132, 1)',
        'rgba(54, 162, 235, 1)',
        'rgba(255, 205, 86, 1)',
        'rgba(75, 192, 192, 1)',
        'rgba(153, 102, 255, 1)',
        'rgba(255, 159, 64, 1)',
        'rgba(255, 193, 7, 1)',
        'rgba(76, 175, 80, 1)',
        'rgba(156, 39, 176, 1)',
        'rgba(96, 125, 139, 1)',
      ];

      return {
        labels: stringLabels,
        datasets: [
          {
            ...dataset,
            backgroundColor:
              dataset.backgroundColor && Array.isArray(dataset.backgroundColor) && dataset.backgroundColor.length >= dataLength
                ? dataset.backgroundColor
                : defaultColors.slice(0, dataLength),
            borderColor:
              dataset.borderColor && Array.isArray(dataset.borderColor) && dataset.borderColor.length >= dataLength
                ? dataset.borderColor
                : defaultBorderColors.slice(0, dataLength),
            borderWidth: dataset.borderWidth || 1,
          },
        ],
      };
    }

    return { ...originalData, labels: stringLabels };
  };

  // Prepare chart options with potential modifications for different chart types
  const prepareChartOptions = (originalOptions, chartType) => {
    const baseOptions = {
      responsive: true,
      maintainAspectRatio: false,
      ...originalOptions,
    };

    // Ensure plugins object exists
    if (!baseOptions.plugins) {
      baseOptions.plugins = {};
    }

    // For pie and doughnut charts, we typically don't need scales
    if (chartType === 'pie' || chartType === 'doughnut') {
      const { scales, ...optionsWithoutScales } = baseOptions;

      // Create a clean legend configuration for pie charts
      const legendConfig = {
        display: true,
        position: 'right',
        labels: {
          usePointStyle: true,
          padding: 15,
          boxWidth: 12,
          font: {
            size: 12,
          },
        },
      };

      // Safely merge tooltip configuration
      const existingTooltip = baseOptions.plugins?.tooltip || {};
      const existingCallbacks = existingTooltip.callbacks || {};

      return {
        ...optionsWithoutScales,
        plugins: {
          ...baseOptions.plugins,
          legend: legendConfig,
          tooltip: {
            enabled: true,
            ...existingTooltip,
            callbacks: {
              ...existingCallbacks,
              label(context) {
                try {
                  const label = context.label || '';
                  const value = context.parsed || 0;
                  const total = context.dataset.data.reduce((sum, val) => sum + val, 0);
                  const percentage = total > 0 ? ((value / total) * 100).toFixed(1) : 0;
                  return `${label}: ${value} (${percentage}%)`;
                } catch (error) {
                  console.error('Error in tooltip callback:', error);
                  return context.label || 'Unknown';
                }
              },
            },
          },
        },
      };
    }

    // For other chart types, ensure tooltip callbacks are properly structured
    if (baseOptions.plugins?.tooltip?.callbacks) {
      const existingCallbacks = baseOptions.plugins.tooltip.callbacks;

      // Validate that callbacks are functions
      Object.keys(existingCallbacks).forEach((callbackName) => {
        if (typeof existingCallbacks[callbackName] !== 'function') {
          console.warn(`Invalid tooltip callback '${callbackName}' - not a function`);
          delete existingCallbacks[callbackName];
        }
      });
    }

    return baseOptions;
  };

  const renderChart = () => {
    if (!currentChartType) return null;

    const { data, options } = plotData;

    // Validate data structure
    if (!data || !data.datasets || !Array.isArray(data.datasets) || data.datasets.length === 0) {
      return (
        <div style={{ padding: '20px', textAlign: 'center', color: 'orange' }}>
          <p>Invalid chart data structure</p>
        </div>
      );
    }

    if (!data.labels || !Array.isArray(data.labels) || data.labels.length === 0) {
      return (
        <div style={{ padding: '20px', textAlign: 'center', color: 'orange' }}>
          <p>Invalid or missing chart labels</p>
        </div>
      );
    }

    // Add debugging for pie chart issues
    if (currentChartType === 'pie' || currentChartType === 'doughnut') {
      console.log('Pie/Doughnut chart data:', data);
      console.log('Pie/Doughnut chart options:', options);
    }

    const chartData = prepareChartData(data, currentChartType);
    const chartOptions = prepareChartOptions(options, currentChartType);

    // Additional debugging for prepared data
    if (currentChartType === 'pie' || currentChartType === 'doughnut') {
      console.log('Prepared chart data:', chartData);
      console.log('Prepared chart options:', chartOptions);
    }

    const chartProps = {
      data: chartData,
      options: chartOptions,
    };

    try {
      switch (currentChartType) {
        case 'bar':
          return <Bar data={chartProps.data} options={chartProps.options} />;
        case 'line':
          return <Line data={chartProps.data} options={chartProps.options} />;
        case 'pie':
          return <Pie data={chartProps.data} options={chartProps.options} />;
        case 'doughnut':
          return <Doughnut data={chartProps.data} options={chartProps.options} />;
        default:
          return <Bar data={chartProps.data} options={chartProps.options} />; // Default to bar chart
      }
    } catch (error) {
      console.error('Chart rendering error:', error);
      return (
        <div style={{ padding: '20px', textAlign: 'center', color: 'red' }}>
          <p>Error rendering {currentChartType} chart</p>
          <p>{error.message}</p>
          <details style={{ marginTop: '10px', textAlign: 'left' }}>
            <summary>Debug Information</summary>
            <pre style={{ fontSize: '10px', maxHeight: '200px', overflow: 'auto' }}>
              {JSON.stringify({ data: chartData, options: chartOptions }, null, 2)}
            </pre>
          </details>
        </div>
      );
    }
  };

  return (
    <Container header={<Header variant="h3">{plotData.options?.title?.text || 'Chart'}</Header>}>
      <Box padding="m">
        <SpaceBetween direction="vertical" size="m">
          {/* Chart type selector */}
          <Box float="right">
            <Select
              selectedOption={selectedOption}
              onChange={handleChartTypeChange}
              options={chartTypeOptions}
              placeholder="Select chart type"
              expandToViewport
            />
          </Box>

          {/* Chart display */}
          <div style={{ height: '400px', width: '100%' }}>{renderChart()}</div>
        </SpaceBetween>
      </Box>
    </Container>
  );
};

PlotDisplay.propTypes = {
  plotData: PropTypes.shape({
    type: PropTypes.string,
    data: PropTypes.shape({
      datasets: PropTypes.arrayOf(PropTypes.shape({})),
      labels: PropTypes.arrayOf(PropTypes.oneOfType([PropTypes.string, PropTypes.number])),
    }),
    options: PropTypes.shape({
      title: PropTypes.shape({
        text: PropTypes.string,
      }),
    }),
  }),
};

export default PlotDisplay;
