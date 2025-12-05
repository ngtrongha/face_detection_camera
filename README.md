# Face Detection Camera

A smart Flutter camera package that detects faces, enforces “look straight” constraints, and automatically captures images. Uses Google ML Kit for face detection, supports custom overlay, rich status builder, and a controller for advanced workflows (like server verification loops).

## Features

- 📸 **Face Detection**: Real-time using ML Kit.
- 🤳 **Auto Capture**: Captures when the face is stable for a configurable duration.
- 🧭 **Look-straight constraints**: Enforce yaw/roll/pitch thresholds; show warning when user not facing forward.
- 🌘 **Encroaching vignette**: Dramatic darkening from edges toward the face; adjustable gap via `vignettePaddingFactor`.
- 🎛 **Controller API**: Pause, resume, capture, switch camera, reset; tweak yaw/roll/pitch thresholds.
- 🎨 **Customization**: `statusBuilder` (rich), `messageBuilder` (legacy), overlay coloring, vignette gap.
- 🔄 **Continuous Workflow**: Capture -> process -> resume without closing the camera.

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
| `messageBuilder` | `Widget? Function(BuildContext, FaceCameraState)` | Legacy message builder. | `null` |
| `statusBuilder` | `Widget? Function(BuildContext, FaceCameraState, bool facingForward, int remainingSeconds)` | Rich builder with facing + countdown info. | `null` |
| `resolutionPreset` | `ResolutionPreset` | Camera resolution. | `ResolutionPreset.high` |
| `initialCameraLensDirection` | `CameraLensDirection` | Start camera (front/back). | `front` |
| `imageFormat` | `CameraImageFormat` | `jpeg` / `png` output. | `jpeg` |
| `enableImageProcessing` | `bool` | Rotate/encode vs raw bytes. | `true` |

### FaceCameraController

| Method | Description |
| --- | --- |
| `initialize()` | Init camera and detector. |
| `pause()` / `resume()` | Pause/resume stability + countdown (preview still runs). |
| `capture()` | Manual capture (resets countdown). |
| `switchCamera()` | Toggle front/back. |
| `dispose()` | Clean resources. |

| Property | Type | Description |
| --- | --- | --- |
| `maxYawDegrees` | `double` | Allowed yaw (turn left/right) to be “facing forward”. |
| `maxRollDegrees` | `double` | Allowed roll (tilt head). |
| `maxPitchDegrees` | `double` | Allowed pitch (look up/down). |
| `facingForward` | `ValueNotifier<bool>` | True when within yaw/roll/pitch limits. |
| `remainingSeconds` | `ValueNotifier<int>` | Countdown seconds (stable phase). |
| `detectedFace` | `ValueNotifier<Face?>` | Latest detected face (for custom overlays). |

## Publishing Checklist

- [ ] Update version in `pubspec.yaml`.
- [ ] Run `flutter pub get`.
- [ ] Run static checks: `flutter analyze`.
- [ ] Run tests: `flutter test`.
- [ ] Update changelog (if any) with recent changes (Uint8List output, vignette padding, facing constraints, statusBuilder).
- [ ] Verify Android/iOS permissions in example app (`CAMERA`, `RECORD_AUDIO`, Info.plist strings).
