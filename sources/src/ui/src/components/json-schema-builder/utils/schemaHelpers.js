import { TYPE_COLORS } from '../../../constants/schemaConstants';

const typeColorCache = new Map();

export const getTypeColor = (type) => {
  if (typeColorCache.has(type)) {
    return typeColorCache.get(type);
  }
  const color = TYPE_COLORS[type] || 'grey';
  typeColorCache.set(type, color);
  return color;
};

export const sanitizeAttribute = (attr) => {
  if (!attr || typeof attr !== 'object') {
    return attr;
  }

  const cleaned = { ...attr };
  delete cleaned.id;
  delete cleaned.name;

  if (cleaned.items) {
    cleaned.items = sanitizeAttribute(cleaned.items);
  }

  if (cleaned.properties) {
    const cleanedProperties = {};
    Object.entries(cleaned.properties).forEach(([key, value]) => {
      cleanedProperties[key] = sanitizeAttribute(value);
    });
    cleaned.properties = cleanedProperties;
  }

  return cleaned;
};

export const generateUniqueId = (prefix = 'item') => {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
};

export const isValidJSON = (str) => {
  try {
    JSON.parse(str);
    return true;
  } catch {
    return false;
  }
};

export const safeParseJSON = (str, fallback = null) => {
  try {
    return JSON.parse(str);
  } catch {
    return fallback;
  }
};

export const buildJSONSchema = (classObj, allClasses = []) => {
  const defs = {};

  allClasses.forEach((cls) => {
    const sanitizedProperties = {};
    Object.entries(cls.attributes?.properties || {}).forEach(([key, value]) => {
      sanitizedProperties[key] = sanitizeAttribute(value);
    });

    defs[cls.name] = {
      type: 'object',
      ...(cls.description ? { description: cls.description } : {}),
      properties: sanitizedProperties,
      ...(cls.attributes.required && cls.attributes.required.length > 0 ? { required: cls.attributes.required } : {}),
    };
  });

  const sanitizedProperties = {};
  Object.entries(classObj.attributes?.properties || {}).forEach(([key, value]) => {
    sanitizedProperties[key] = sanitizeAttribute(value);
  });

  return {
    $schema: 'https://json-schema.org/draft/2020-12/schema',
    $id: classObj.name,
    type: 'object',
    ...(classObj.description ? { description: classObj.description } : {}),
    properties: sanitizedProperties,
    ...(classObj.attributes.required && classObj.attributes.required.length > 0 ? { required: classObj.attributes.required } : {}),
    $defs: defs,
  };
};

export const formatValueForInput = (value) => {
  if (value === undefined || value === null) return '';
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
};

export const parseInputValue = (input, originalType = 'string') => {
  if (!input || !input.trim()) return undefined;

  if (originalType === 'object' || originalType === 'array') {
    return safeParseJSON(input, input);
  }

  if (originalType === 'number' || originalType === 'integer') {
    const num = parseFloat(input);
    return Number.isNaN(num) ? input : num;
  }

  return input;
};
