# Changelog

## 0.3.1

### New Features
- **Per-challenge image capture**: Each `LivenessChallengeResult` now includes a `capturedImage` field, captured at the moment the challenge completes or fails.
- **Configurable `challengeDelay`**: Delay between challenges is now customizable via `LivenessCameraWidget.challengeDelay` (default: 500ms).

### Improvements
- **Safer image processing**: `_processImageIsolate` now deletes the file **after** successful decode instead of before, preventing permanent image loss on decode failure.
- `LivenessResult.capturedImage` is now set from the last challenge's image (no extra capture call).

### Bug Fixes
- **Liveness `capturedImage` always null**: `LivenessController._completeFlow()` now captures an image via `captureCallback` before creating `LivenessResult`, populated on both **pass** and **fail**.
- **`autoStart = false` unusable**: Added a "Start" button UI when `autoStart` is `false`, and exposed `startLiveness()` method on `_LivenessCameraWidgetState`.
- **Crash after dispose (async `_completeFlow`)**: Added `_isDisposed` guard throughout `LivenessController` to prevent accessing disposed ValueNotifiers after async operations.
- **Crash from `Future.delayed` after pop**: `_successChallenge` now guards the 500ms delay with `_isDisposed` and state checks.
- **`_holdTimer` passes challenge without face**: Added `onFaceLost()` method; `LivenessCameraWidget` calls it when face becomes `null`, cancelling the hold timer.
- **Missing app lifecycle handling**: Added `WidgetsBindingObserver` to `LivenessCameraWidget` to pause camera & cancel timers on background.
- **Anti-spoofing too strict**: Replaced instant-fail on tracking ID change with tolerant `maxTrackingIdChanges` (default: 3).
- **Capture state collision**: `FaceCameraController.capture()` now uses a `Completer` so concurrent calls wait for the ongoing capture instead of returning silently.
- **Wrong default threshold for turn/nod**: `LivenessChallengeConfig.threshold` now defaults to 20° for turn/nod challenges (was 0.5, which meant any tiny movement would pass).

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
