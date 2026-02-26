// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
import React from 'react';
import { createRoot } from 'react-dom/client';
import './index.css';

import App from './App';

// Suppress ResizeObserver loop error - this is a benign browser timing issue
const originalConsoleError = console.error;
console.error = (...args) => {
  if (args[0]?.includes?.('ResizeObserver loop') || args[0]?.message?.includes?.('ResizeObserver loop')) {
    return;
  }
  originalConsoleError(...args);
};

// Catch ResizeObserver errors at the window level
window.addEventListener('error', (e) => {
  if (e.message?.includes('ResizeObserver loop')) {
    e.stopImmediatePropagation();
    e.preventDefault();
  }
  return true;
});

// Catch unhandled promise rejections
window.addEventListener('unhandledrejection', (e) => {
  if (e.reason?.message?.includes('ResizeObserver loop')) {
    e.stopImmediatePropagation();
    e.preventDefault();
  }
  return true;
});

const root = createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
