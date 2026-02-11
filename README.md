# Face Detection Camera

A smart Flutter camera package that detects faces, enforces "look straight" constraints, automatically captures images, and supports advanced **Liveness Detection** (anti-spoofing). Uses Google ML Kit for face detection, supports custom overlays, rich status builders, and a modular architecture for professional workflows.

## Features

- 📸 **Face Detection**: Real-time using ML Kit with tracking support.
- 🤳 **Auto Capture**: Captures when the face is stable for a configurable duration.
- 🛡️ **Liveness Detection**: Anti-spoofing challenges (blink, smile, turn head, nod) with animated progress indicators.
- 🧭 **Look-straight constraints**: Enforce yaw/roll/pitch thresholds; show warning when user not facing forward.
- 🌘 **Encroaching vignette**: Dramatic darkening from edges toward the face; adjustable gap via `vignettePaddingFactor`.
- 🎛 **Modular Controller API**: Specialized services for Camera, Detection, Stability, and Liveness.
- 🎨 **Deep Customization**: `statusBuilder`, `instructionBuilder`, `progressBuilder`, custom colors, icons, and magic numbers.
- 🔄 **Continuous Workflow**: Capture -> process -> resume without closing the camera.
- 🔦 **Flash Control**: Toggle flash/torch mode for low-light environments.
- ✂️ **Face Cropping**: Optionally crop captured image to face bounding box.
- 🎯 **Face Landmarks**: Enable contours and classification (smiling, eyes open) detection.
- 📱 **Orientation Lock**: Automatic portrait orientation locking.
- ⚠️ **Error Handling**: Comprehensive error callbacks for permission, initialization, and capture failures.
- 🇻🇳 **Bilingual Support**: Full API documentation in both English and Vietnamese.

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  face_detection_camera:
    path: ./ # Or git/pub version
```

## Setup

### Android

Add the following permissions to your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

Set the `minSdkVersion` to at least 21 in `android/app/build.gradle`.

### iOS

Add the following keys to your `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to detect faces and take photos.</string>
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access for camera.</string>
```

## Usage

### 1. Basic Auto Capture

```dart
import 'package:face_detection_camera/face_detection_camera.dart';

SmartFaceCamera(
  autoCapture: true,
  captureCountdownDuration: 3000,
  onCapture: (Uint8List imageBytes) {
    // Handle captured JPEG/PNG bytes
  },
)
```

### 2. Liveness Detection (Banking-app Style)

```dart
LivenessCameraWidget(
  challenges: [
    LivenessChallengeConfig(
      challenge: LivenessChallenge.blink,
      instructionText: 'Please blink your eyes',
    ),
    LivenessChallengeConfig(
      challenge: LivenessChallenge.turnLeft,
      instructionText: 'Turn your head left',
    ),
  ],
  onLivenessComplete: (LivenessResult result) {
    if (result.passed) {
       // result.capturedImage contains the final image
    }
  },
)
```

### 3. Advanced Customization

Every threshold and visual element is now customizable:

```dart
SmartFaceCamera(
  maxYawDegrees: 15.0,        // Max left/right turn
  maxRollDegrees: 10.0,       // Max head tilt
  minQualityScore: 0.7,       // Minimum image quality (0.0 - 1.0)
  vignettePaddingFactor: 1.2, // Gap around the face
  onCapture: (bytes) { ... },
)
```

## Modular Architecture

The package is now built with a service-based architecture for better stability and control:

- **`CameraService`**: Lifecycle, resolution, flash, and zoom.
- **`FaceDetectionService`**: ML Kit integration and image stream processing.
- **`StabilityTracker`**: Face stability and capture countdown logic.
- **`LivenessController`**: Challenge sequencing and flow management.

## Configuration

### SmartFaceCamera

| Parameter | Type | Description | Default |
| --- | --- | --- | --- |
| `onCapture` | `Function(Uint8List)` | Captured image bytes. | Required |
| `autoCapture` | `bool` | Auto capture when stable. | `true` |
| `captureCountdownDuration` | `int` | Countdown duration (ms). | `3000` |
| `maxYawDegrees` | `double` | Max yaw for frontal face. | `12.0` |
| `minQualityScore` | `double` | Min quality for capture. | `0.0` |
| `showControls` | `bool` | Show camera switch button. | `false` |
| `cropToFace` | `bool` | Crop image to face bounds. | `false` |

### LivenessCameraWidget

| Parameter | Type | Description |
| --- | --- | --- |
| `challenges` | `List<LivenessChallengeConfig>` | List of actions to perform. |
| `onLivenessComplete` | `Function(LivenessResult)` | Final result callback. |
| `instructionBuilder` | `Widget Function(...)` | Custom instruction UI. |
| `progressBuilder` | `Widget Function(BuildContext, LivenessProgressInfo)` | Custom progress UI; use `progress.overallProgress`, `progress.currentIndex`, etc. |

## Exported Types

The package exports everything needed for deep integration:
`SmartFaceCamera`, `LivenessCameraWidget`, `FaceCameraController`, `LivenessController`, `FaceCameraState`, `FaceCameraError`, `LivenessChallenge`, `LivenessChallengeConfig`, `LivenessResult`, `FaceQuality`, `Face`.
