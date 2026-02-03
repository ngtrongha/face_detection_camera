# Changelog

## 0.2.0

### New Features
- **Multiple Face Detection**: Added `detectMultipleFaces`, `maxFaces`, and `onMultipleFacesDetected` callback
- **Face Quality Score**: Added `FaceQuality` class with brightness, sharpness, and pose metrics
- **Manual Capture Button**: Added `showCaptureButton` and `captureButtonBuilder` for custom UI
- **Preview Mode**: Added `showPreview`, `onPreviewConfirm`, and `onPreviewRetry` callbacks
- **Zoom Control**: Added pinch-to-zoom with `enableZoom`, `minZoom`, `maxZoom`, and `zoomLevel` notifier
- **Capture Sound**: Added `enableCaptureSound` option

### Optimizations
- **Error Recovery**: Auto-retry camera initialization with exponential backoff (`maxRetryAttempts`)
- **Memory**: Proper disposal of all ValueNotifiers and resources

### Previous (0.1.0)
- Flash/torch control
- Configurable JPEG quality
- Face cropping to bounding box
- Error callbacks with `FaceCameraError` enum
- Face landmarks/contours detection
- Device orientation locking
