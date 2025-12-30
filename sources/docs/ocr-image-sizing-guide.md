# OCR Image Sizing Best Practices Guide

## Overview

The OCR service automatically applies sensible default image size limits to optimize the balance between OCR accuracy and resource consumption. This guide explains the sizing strategy and how to customize it for your specific use cases.

## Default Behavior (NEW)

### Automatic Optimization
- **Default limits**: 951x1268 pixels when no image sizing is configured
- **Why defaults matter**: Prevents excessive token consumption, memory issues, and processing delays
- **Backward compatibility**: Existing explicit configurations continue to work unchanged

### When Defaults Are Applied
```yaml
ocr:
  image:
    # No target_width or target_height specified
    # → Automatic 951x1268 limits applied
    dpi: 150
```

### When Defaults Are NOT Applied
```yaml
ocr:
  image:
    # Explicit configuration provided
    target_width: 1200
    target_height: 900
    # → Your explicit values used
```

## Sizing Recommendations by Use Case

| Use Case | Dimensions | Token Usage/Page | Best For | Configuration |
|----------|------------|------------------|----------|---------------|
| **High Accuracy** | 1600×1200 | 500-800 | Forms, tables, handwriting | `target_width: 1600`<br/>`target_height: 1200` |
| **Standard Documents** | 1200×900 | 300-500 | Printed text, simple layouts | `target_width: 1200`<br/>`target_height: 900` |
| **Token-Conscious** | 800×600 | 150-300 | Basic text extraction | `target_width: 800`<br/>`target_height: 600` |
| **Minimal Processing** | 600×450 | 100-200 | Speed over accuracy | `target_width: 600`<br/>`target_height: 450` |
| **No Limits** | Original | 1000-4000+ | When quality is critical | `target_width: ""`<br/>`target_height: ""` |

## Cost Impact Analysis

### Before Default Sizing
- **Typical page**: 1000-4000+ tokens
- **10-page document**: 40,000+ tokens
- **Monthly cost impact**: Can be substantial for high-volume processing

### With Default Sizing (951×1268)
- **Typical page**: 400-600 tokens
- **10-page document**: ~5,000 tokens
- **Cost reduction**: 60-85% on vision model costs

### Resource Benefits
- **Memory usage**: Reduced OutOfMemory errors during concurrent processing
- **Processing speed**: Faster uploads, downloads, and processing
- **Network efficiency**: Lower bandwidth consumption

## Configuration Examples

### Use Automatic Defaults (Recommended)
```yaml
ocr:
  image:
    dpi: 150
    # No sizing specified = automatic 951×1268 defaults applied
```

### High-Volume Text Processing
```yaml
ocr:
  image:
    dpi: 150
    target_width: 1200
    target_height: 900
    # Balances quality with token efficiency
```

### Forms and Complex Documents  
```yaml
ocr:
  image:
    dpi: 150
    target_width: 1600
    target_height: 1200
    # Maximum recommended size for accuracy
```

### Token-Optimized Processing
```yaml
ocr:
  image:
    dpi: 150
    target_width: 800  
    target_height: 600
    # Minimizes token usage while maintaining readability
```

### Working with Configuration Systems
```yaml
# Empty strings are treated the same as no configuration
# This handles configuration systems that return empty strings for unset values
ocr:
  image:
    dpi: 150
    target_width: ""
    target_height: ""
    # → Automatic 951x1268 defaults applied (same as if not specified)
```

### Partial Configuration (Disables Defaults)
```yaml
ocr:
  image:
    dpi: 150
    target_width: 800
    # target_height missing - disables automatic defaults
    # → No size limits applied (preserves existing behavior)
```

## Migration Guide

### For Existing Deployments
1. **No action required**: Existing configurations continue to work
2. **Opt into defaults**: Remove `target_width` and `target_height` from config
3. **Monitor improvements**: Track token usage and processing performance

### Performance Monitoring
- Monitor token consumption in LLM processing stages
- Watch for memory usage improvements during concurrent processing
- Track overall document processing times

## Troubleshooting

### OCR Quality Issues
- **Text unclear**: Increase image dimensions or check source document quality
- **Tables misaligned**: Try 1600×1200 or higher for complex layouts
- **Handwriting errors**: Use maximum recommended sizing (1600×1200)

### Performance Issues  
- **Memory errors**: Ensure sizing limits are applied (not disabled)
- **Slow processing**: Reduce image dimensions if quality permits
- **High costs**: Monitor and optimize based on use case requirements

## Best Practices Summary

1. **Start with defaults**: Let automatic sizing optimize your resource usage
2. **Measure and adjust**: Monitor token usage and accuracy for your specific documents
3. **Use case specific**: Different document types may benefit from different sizing
4. **Test thoroughly**: Validate OCR accuracy with your specific document samples
5. **Monitor costs**: Track token consumption impact of sizing decisions

## Technical Details

### How Defaults Work
- Applied when both `target_width` and `target_height` are unspecified or `None`
- Fallback to defaults when invalid values are provided
- Partial configurations (only width OR height) disable defaults to preserve existing behavior

### Memory Optimization
- Images are extracted at target size to prevent memory issues
- Concurrent processing optimized to avoid OutOfMemory errors
- Aggressive memory cleanup after each page processing

### Aspect Ratio Preservation
- All resizing preserves original aspect ratio
- Never upscales images (quality would not improve)
- Uses intelligent scaling to fit within target dimensions

## Logging and Monitoring

### Configuration Visibility
```
INFO OCR Service initialized - DPI: 150, Image sizing: 1600x1200
```

### Default Application
```
INFO No image sizing configured, applying default limits: 1600x1200 to optimize resource usage and token consumption
```

### Explicit Configuration
```
INFO Using configured image sizing: 800x600
```

### Error Handling
```
WARNING Invalid resize configuration values: width=abc, height=xyz. Falling back to defaults: 1600x1200
```

This comprehensive logging helps you understand exactly what sizing strategy is being applied and troubleshoot any configuration issues.
