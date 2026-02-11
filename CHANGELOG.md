# Changelog

## 0.3.0

### New Features
- **Liveness Detection**: Integrated a flexible banking-app style liveness flow with customizable challenges (blink, smile, turn left/right, nod up/down).
- **LivenessCameraWidget**: New specialized widget for handling the entire liveness flow with built-in UI and animations.
- **Bilingual Documentation**: Added comprehensive API comments in both English and Vietnamese.

### Architectural Improvements
- **Modular Refactoring (SRP)**: Decomposed the monolithic controller and widget into specialized services:
    - `CameraService`: Manages camera lifecycle, flash, and zoom.
    - `FaceDetectionService`: Handles ML Kit integration and face data processing.
    - `StabilityTracker`: Manages face stability and capture countdown.
    - `LivenessController`: Orchestrates challenge sequencing and flow.
- **Sub-widget Extraction**: Moved complex UI components into modular sub-widgets for better maintainability.

### Bug Fixes & Optimizations
- **App Lifecycle Handling**: Fixed camera issues when moving the app to background/foreground.
- **Memory Management**: Ensured proper disposal of all controllers and ValueNotifiers to prevent leaks.
- **Double File Deletion**: Resolved a redundant file delete operation during the capture flow.
- **Improved Metrics**: Refined `FaceQuality` calculations with a more stable brightness estimation.
- **Enhanced Customization**: Exposed all internal thresholds, colors, icons, and builders as parameters.

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

## 0.1.0
- Initial public release with basic face detection and auto-capture.
