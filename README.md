# Face Detection Camera

A smart Flutter camera package that detects faces, enforces "look straight" constraints, and automatically captures images. Uses Google ML Kit for face detection, supports custom overlay, rich status builder, and a controller for advanced workflows (like server verification loops).

## Features

- 📸 **Face Detection**: Real-time using ML Kit.
- 🤳 **Auto Capture**: Captures when the face is stable for a configurable duration.
- 🧭 **Look-straight constraints**: Enforce yaw/roll/pitch thresholds; show warning when user not facing forward.
- 🌘 **Encroaching vignette**: Dramatic darkening from edges toward the face; adjustable gap via `vignettePaddingFactor`.
- 🎛 **Controller API**: Pause, resume, capture, switch camera, reset; tweak yaw/roll/pitch thresholds.
- 🎨 **Customization**: `statusBuilder` (rich), `messageBuilder` (legacy), overlay coloring, vignette gap.
- 🔄 **Continuous Workflow**: Capture -> process -> resume without closing the camera.
- 🔦 **Flash Control**: Toggle flash/torch mode for low-light environments.
- ✂️ **Face Cropping**: Optionally crop captured image to face bounding box.
- 🎯 **Face Landmarks**: Enable contours and classification (smiling, eyes open) detection.
- 📱 **Orientation Lock**: Automatic portrait orientation locking.
- ⚠️ **Error Handling**: Comprehensive error callbacks for permission, initialization, and capture failures.

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

### Basic Usage (quick start)

```dart
import 'package:face_detection_camera/face_detection_camera.dart';

SmartFaceCamera(
  autoCapture: true,
  captureCountdownDuration: 3000, // ms stable before capture
  vignettePaddingFactor: 1.1,     // gap from face to vignette
  onCapture: (Uint8List imageBytes) {
    // handle captured bytes (JPEG by default)
  },
  statusBuilder: (context, state, facingForward, remainingSeconds) {
    if (!facingForward) return Text('Please look straight at the camera');
    if (state == FaceCameraState.stable) {
      return Text('Hold still... ($remainingSeconds)');
    }
    return null; // fallback to defaults
  },
)
```

### Advanced Usage: Server Processing Loop

For use cases where you need to capture an image, pause camera logic, send to server, then resume:

1. Create a `FaceCameraController`.
2. Pass it to `SmartFaceCamera`.
3. Use `pause()` and `resume()` in the `onCapture` callback.

```dart
class MyCameraScreen extends StatefulWidget {
  @override
  _MyCameraScreenState createState() => _MyCameraScreenState();
}

class _MyCameraScreenState extends State<MyCameraScreen> {
  late FaceCameraController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FaceCameraController(
      autoCapture: true,
      captureCountdownDuration: 2000,
      // tighten facing constraints if needed
      maxYawDegrees: 10,
      maxRollDegrees: 10,
      maxPitchDegrees: 10,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SmartFaceCamera(
        controller: _controller,
        onCapture: (Uint8List imageBytes) async {
          // 1. Pause detection immediately so we don't capture again while processing
          _controller.pause();

          // 2. Show a loading dialog or process the image
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator()),
          );

          // 3. Simulate server upload
          await Future.delayed(const Duration(seconds: 2));
          
          // Close dialog
          Navigator.pop(context);

          // 4. Resume detection for the next user/attempt
          _controller.resume();
        },
      ),
    );
  }
}
```

### Error Handling

```dart
SmartFaceCamera(
  onCapture: (bytes) { /* ... */ },
  onError: (FaceCameraError error, String? message) {
    switch (error) {
      case FaceCameraError.permissionDenied:
        print('Camera permission denied');
        break;
      case FaceCameraError.cameraInitFailed:
        print('Failed to initialize camera: $message');
        break;
      case FaceCameraError.captureFailed:
        print('Failed to capture image: $message');
        break;
      case FaceCameraError.noCamera:
        print('No camera available');
        break;
      default:
        print('Unknown error: $message');
    }
  },
)
```

### Face Cropping

```dart
SmartFaceCamera(
  cropToFace: true,          // Enable face cropping
  faceCropPadding: 1.5,      // Padding around face (1.5 = 50% extra)
  onCapture: (bytes) {
    // bytes will be cropped to just the face area
  },
)
```

### Flash Control

```dart
SmartFaceCamera(
  showFlashButton: true,           // Show flash toggle button
  initialFlashMode: FlashMode.off, // Start with flash off
  onCapture: (bytes) { /* ... */ },
)

// Or control programmatically:
_controller.toggleFlash();
_controller.setFlashMode(FlashMode.torch);
```

## Configuration

### SmartFaceCamera

| Parameter | Type | Description | Default |
| --- | --- | --- | --- |
| `onCapture` | `Function(Uint8List)` | Captured image bytes (JPEG/PNG). | Required |
| `controller` | `FaceCameraController?` | External controller (pause/resume/capture/switch). | `null` |
| `autoCapture` | `bool` | Auto capture when stable. | `true` |
| `captureCountdownDuration` | `int` | Stable duration before capture (ms). | `3000` |
| `vignettePaddingFactor` | `double` | Gap from face to dark vignette (bigger = wider clear area). | `1.1` |
| `showControls` | `bool` | Show switch camera button. | `false` |
| `showFlashButton` | `bool` | Show flash toggle button. | `false` |
| `messageBuilder` | `Widget? Function(BuildContext, FaceCameraState)` | Legacy message builder. | `null` |
| `statusBuilder` | `StatusMessageBuilder` | Rich builder with facing + countdown info. | `null` |
| `resolutionPreset` | `ResolutionPreset` | Camera resolution. | `ResolutionPreset.high` |
| `initialCameraLensDirection` | `CameraLensDirection` | Start camera (front/back). | `front` |
| `imageFormat` | `CameraImageFormat` | `jpeg` / `png` output. | `jpeg` |
| `enableImageProcessing` | `bool` | Rotate/encode vs raw bytes. | `true` |
| `jpegQuality` | `int` | JPEG quality (1-100). | `90` |
| `cropToFace` | `bool` | Crop captured image to face bounds. | `false` |
| `faceCropPadding` | `double` | Padding around face when cropping. | `1.5` |
| `enableContours` | `bool` | Enable face contours detection. | `false` |
| `enableClassification` | `bool` | Enable smile/eyes classification. | `false` |
| `initialFlashMode` | `FlashMode` | Initial flash mode. | `FlashMode.off` |
| `lockOrientation` | `bool` | Lock to portrait orientation. | `true` |
| `onError` | `FaceCameraErrorCallback?` | Error callback. | `null` |
| `maxYawDegrees` | `double` | Max yaw for facing forward. | `12.0` |
| `maxRollDegrees` | `double` | Max roll for facing forward. | `12.0` |
| `maxPitchDegrees` | `double` | Max pitch for facing forward. | `12.0` |

### FaceCameraController

| Method | Description |
| --- | --- |
| `initialize()` | Init camera and detector. |
| `pause()` / `resume()` | Pause/resume stability + countdown (preview still runs). |
| `capture()` | Manual capture (resets countdown). |
| `switchCamera()` | Toggle front/back. |
| `toggleFlash()` | Toggle flash off/torch. |
| `setFlashMode(FlashMode)` | Set specific flash mode. |
| `reset()` | Reset to searching state. |
| `dispose()` | Clean resources. |

| Property | Type | Description |
| --- | --- | --- |
| `state` | `FaceCameraState` | Current camera state. |
| `maxYawDegrees` | `double` | Allowed yaw (turn left/right) to be "facing forward". |
| `maxRollDegrees` | `double` | Allowed roll (tilt head). |
| `maxPitchDegrees` | `double` | Allowed pitch (look up/down). |
| `facingForward` | `ValueNotifier<bool>` | True when within yaw/roll/pitch limits. |
| `remainingSeconds` | `ValueNotifier<int>` | Countdown seconds (stable phase). |
| `detectedFace` | `ValueNotifier<Face?>` | Latest detected face (for custom overlays). |
| `flashMode` | `ValueNotifier<FlashMode>` | Current flash mode. |
| `capturedImage` | `Uint8List?` | Last captured image bytes. |

## Exported Types

The package exports the following types for customization:

- `SmartFaceCamera` - Main camera widget
- `FaceCameraController` - Controller for programmatic control
- `FaceCameraState` - Enum of camera states
- `FaceCameraError` - Enum of error types
- `FaceOverlay` - Overlay widget for custom UI
- `FacePainter` - CustomPainter for face vignette
- `CameraImageFormat` - Image format enum (jpeg/png)
- `Face` - ML Kit Face object
- `FlashMode` - Camera flash modes
- `ResolutionPreset` - Camera resolution presets
- `CameraLensDirection` - Front/back camera
