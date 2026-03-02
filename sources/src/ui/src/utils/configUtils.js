// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

/**
 * Deep merge utility for configuration objects.
 *
 * @param {Object} target - Base object
 * @param {Object} source - Object to merge on top
 * @returns {Object} Merged object
 */
export const deepMerge = (target, source) => {
  const result = { ...target };

  if (!source) {
    return result;
  }

  Object.keys(source)
    .filter((key) => Object.hasOwn(source, key))
    .forEach((key) => {
      if (source[key] && typeof source[key] === 'object' && !Array.isArray(source[key])) {
        if (Object.hasOwn(target, key) && target[key] && typeof target[key] === 'object') {
          result[key] = deepMerge(target[key], source[key]);
        } else {
          result[key] = { ...source[key] };
        }
      } else {
        result[key] = source[key];
      }
    });

  return result;
};
