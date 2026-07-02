// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

/* eslint-disable react/no-array-index-key */

/**
 * PdfPageSelector — renders page thumbnails from a local PDF file and lets
 * the user define page ranges for multi-section discovery.
 *
 * Uses pdfjs-dist (Mozilla PDF.js) to render thumbnails entirely in the browser
 * from the local File object — no backend round-trip needed for the preview.
 */

import React, { useState, useEffect, useCallback } from 'react';
import { Box, Button, SpaceBetween, Input, StatusIndicator } from '@cloudscape-design/components';

// Color palette for page range highlighting
const RANGE_COLORS = [
  'rgba(0, 115, 187, 0.25)', // blue
  'rgba(21, 132, 67, 0.25)', // green
  'rgba(232, 114, 0, 0.25)', // orange
  'rgba(148, 64, 196, 0.25)', // purple
  'rgba(201, 37, 45, 0.25)', // red
  'rgba(0, 168, 168, 0.25)', // teal
];

const RANGE_BORDER_COLORS = ['#0073bb', '#158443', '#e87200', '#9440c4', '#c9252d', '#00a8a8'];

export interface PageRange {
  start: number;
  end: number;
  label?: string;
}

interface PdfPageSelectorProps {
  file: File | null;
  pageRanges: PageRange[];
  onPageRangesChange: (ranges: PageRange[]) => void;
  disabled?: boolean;
  onAutoDetect?: () => void;
  isAutoDetecting?: boolean;
}

/** Validate a single range string like "3-5" */
const isValidRangeInput = (value: string): boolean => {
  return /^\d+$/.test(value.trim());
};

const PdfPageSelector: React.FC<PdfPageSelectorProps> = ({
  file,
  pageRanges,
  onPageRangesChange,
  disabled = false,
  onAutoDetect,
  isAutoDetecting = false,
}) => {
  const [thumbnails, setThumbnails] = useState<string[]>([]);
  const [numPages, setNumPages] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);

  // Load PDF and render thumbnails when file changes
  useEffect(() => {
    if (!file || !file.name.toLowerCase().endsWith('.pdf')) {
      setThumbnails([]);
      setNumPages(0);
      setLoadError(null);
      return;
    }

    let cancelled = false;

    const renderThumbnails = async () => {
      setIsLoading(true);
      setLoadError(null);
      setThumbnails([]);

      try {
        // Dynamic import for code splitting — pdfjs-dist is ~2MB
        const pdfjsLib = await import('pdfjs-dist');

        // Set worker source (uses bundled worker)
        pdfjsLib.GlobalWorkerOptions.workerSrc = new URL('pdfjs-dist/build/pdf.worker.mjs', import.meta.url).toString();

        // Read file as ArrayBuffer
        const arrayBuffer = await file.arrayBuffer();
        if (cancelled) return;

        // Load PDF document
        const pdf = await pdfjsLib.getDocument({ data: arrayBuffer }).promise;
        if (cancelled) return;

        const totalPages = pdf.numPages;
        setNumPages(totalPages);

        // Render each page as a small thumbnail
        const thumbs: string[] = [];
        const THUMB_WIDTH = 120;

        for (let i = 1; i <= totalPages; i++) {
          if (cancelled) break;

          const page = await pdf.getPage(i);
          const viewport = page.getViewport({ scale: 1 });
          const scale = THUMB_WIDTH / viewport.width;
          const scaledViewport = page.getViewport({ scale });

          // Create an off-screen canvas for rendering
          const canvas = document.createElement('canvas');
          canvas.width = scaledViewport.width;
          canvas.height = scaledViewport.height;
          const ctx = canvas.getContext('2d');

          if (ctx) {
            await page.render({
              canvasContext: ctx,
              viewport: scaledViewport,
            }).promise;
            thumbs.push(canvas.toDataURL('image/jpeg', 0.7));
          }

          page.cleanup();
        }

        if (!cancelled) {
          setThumbnails(thumbs);
        }
      } catch (err) {
        if (!cancelled) {
          console.error('Error rendering PDF thumbnails:', err);
          setLoadError(`Failed to load PDF preview: ${(err as Error).message}`);
        }
      } finally {
        if (!cancelled) {
          setIsLoading(false);
        }
      }
    };

    renderThumbnails();

    return () => {
      cancelled = true;
    };
  }, [file]);

  /** Determine which color index a page belongs to (or -1 if no range) */
  const getPageRangeIndex = useCallback(
    (pageNum: number): number => {
      for (let i = 0; i < pageRanges.length; i++) {
        if (pageNum >= pageRanges[i].start && pageNum <= pageRanges[i].end) {
          return i;
        }
      }
      return -1;
    },
    [pageRanges],
  );

  const addRange = () => {
    // Default: next unassigned page or page 1
    const lastEnd = pageRanges.length > 0 ? pageRanges[pageRanges.length - 1].end : 0;
    const newStart = Math.min(lastEnd + 1, numPages);
    const newEnd = numPages;
    onPageRangesChange([...pageRanges, { start: newStart, end: newEnd }]);
  };

  const removeRange = (index: number) => {
    const updated = [...pageRanges];
    updated.splice(index, 1);
    onPageRangesChange(updated);
  };

  const updateRange = (index: number, field: 'start' | 'end', value: string) => {
    if (!isValidRangeInput(value) && value !== '') return;
    const num = parseInt(value, 10);
    if (value !== '' && (isNaN(num) || num < 1 || num > numPages)) return;

    const updated = [...pageRanges];
    if (value === '') {
      updated[index] = { ...updated[index], [field]: field === 'start' ? 1 : numPages };
    } else {
      updated[index] = { ...updated[index], [field]: num };
    }
    onPageRangesChange(updated);
  };

  // Don't render if no PDF is selected
  if (!file || !file.name.toLowerCase().endsWith('.pdf')) {
    return null;
  }

  return (
    <Box padding={{ top: 's' }}>
      {/* Thumbnail grid */}
      {isLoading && (
        <Box padding="s">
          <StatusIndicator type="loading">Loading PDF pages...</StatusIndicator>
        </Box>
      )}

      {loadError && (
        <Box padding="s">
          <StatusIndicator type="error">{loadError}</StatusIndicator>
        </Box>
      )}

      {thumbnails.length > 0 && (
        <Box>
          <Box variant="h4" margin={{ bottom: 'xs' }}>
            📄 Document Preview ({numPages} pages)
          </Box>
          <Box fontSize="body-s" color="text-body-secondary" margin={{ bottom: 's' }}>
            Define page ranges below to discover multiple classes from different sections of this document. Each range will create a
            separate discovery job.
          </Box>

          {/* Thumbnail strip */}
          <div
            style={{
              display: 'flex',
              flexWrap: 'wrap',
              gap: '8px',
              marginBottom: '16px',
              padding: '8px',
              backgroundColor: '#fafafa',
              borderRadius: '8px',
              border: '1px solid #e0e0e0',
            }}
          >
            {thumbnails.map((thumb, idx) => {
              const pageNum = idx + 1;
              const rangeIdx = getPageRangeIndex(pageNum);
              const bgColor = rangeIdx >= 0 ? RANGE_COLORS[rangeIdx % RANGE_COLORS.length] : 'transparent';
              const borderColor = rangeIdx >= 0 ? RANGE_BORDER_COLORS[rangeIdx % RANGE_BORDER_COLORS.length] : '#d5dbdb';

              return (
                <div
                  key={`thumb-${pageNum}`}
                  style={{
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    padding: '4px',
                    borderRadius: '6px',
                    border: `2px solid ${borderColor}`,
                    backgroundColor: bgColor,
                    transition: 'all 0.2s ease',
                    cursor: 'default',
                  }}
                >
                  <img
                    src={thumb}
                    alt={`Page ${pageNum}`}
                    style={{
                      width: '80px',
                      height: 'auto',
                      borderRadius: '2px',
                      boxShadow: '0 1px 3px rgba(0,0,0,0.12)',
                    }}
                  />
                  <Box fontSize="body-s" fontWeight={rangeIdx >= 0 ? 'bold' : 'normal'} margin={{ top: 'xxs' }}>
                    {pageNum}
                  </Box>
                </div>
              );
            })}
          </div>

          {/* Page range inputs */}
          <SpaceBetween size="xs">
            {pageRanges.map((range, idx) => (
              <div
                key={`range-${range.start}-${range.end}-${idx}`}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  padding: '6px 10px',
                  borderRadius: '6px',
                  borderLeft: `4px solid ${RANGE_BORDER_COLORS[idx % RANGE_BORDER_COLORS.length]}`,
                  backgroundColor: RANGE_COLORS[idx % RANGE_COLORS.length],
                }}
              >
                <div style={{ minWidth: '70px' }}>
                  <Box fontSize="body-s" fontWeight="bold" color="text-body-secondary">
                    Range {idx + 1}:
                  </Box>
                </div>
                <Box fontSize="body-s">Pages</Box>
                <div style={{ width: '70px' }}>
                  <Input
                    value={String(range.start)}
                    onChange={({ detail }) => updateRange(idx, 'start', detail.value)}
                    type="number"
                    disabled={disabled}
                    inputMode="numeric"
                  />
                </div>
                <Box fontSize="body-s">to</Box>
                <div style={{ width: '70px' }}>
                  <Input
                    value={String(range.end)}
                    onChange={({ detail }) => updateRange(idx, 'end', detail.value)}
                    type="number"
                    disabled={disabled}
                    inputMode="numeric"
                  />
                </div>
                <Box fontSize="body-s" color="text-body-secondary">
                  ({range.end - range.start + 1} page{range.end - range.start + 1 !== 1 ? 's' : ''})
                </Box>
                <div style={{ flex: 1, minWidth: '120px' }}>
                  <Input
                    value={range.label || ''}
                    onChange={({ detail }) => {
                      const updated = [...pageRanges];
                      updated[idx] = { ...updated[idx], label: detail.value };
                      onPageRangesChange(updated);
                    }}
                    placeholder="Document type (optional)"
                    disabled={disabled}
                  />
                </div>
                <Button
                  iconName="close"
                  variant="icon"
                  onClick={() => removeRange(idx)}
                  disabled={disabled}
                  ariaLabel={`Remove range ${idx + 1}`}
                />
              </div>
            ))}

            <SpaceBetween size="xs" direction="horizontal">
              <Button iconName="add-plus" onClick={addRange} disabled={disabled || isAutoDetecting || numPages === 0} variant="link">
                Add page range
              </Button>
              {onAutoDetect && (
                <Button
                  onClick={onAutoDetect}
                  loading={isAutoDetecting}
                  disabled={disabled || isAutoDetecting || numPages === 0}
                  variant="link"
                >
                  ✨ Auto-detect sections
                </Button>
              )}
            </SpaceBetween>
          </SpaceBetween>
        </Box>
      )}
    </Box>
  );
};

export default PdfPageSelector;
