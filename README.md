# Face Detection Camera

A smart Flutter camera package that detects faces, ensures stability, and automatically captures images. It uses Google's ML Kit for face detection and provides a customizable overlay and controller for advanced workflows (like server-side verification loops).

## Features

- 📸 **Face Detection**: Real-time face detection using ML Kit.
- 🤳 **Auto Capture**: Automatically captures an image when the face is stable for a set duration.
- ⏳ **Stability Countdown**: Visual countdown feedback when the user holds still.
- 🎛 **Controller API**: Full control over the camera flow (pause, resume, capture, reset) via `FaceCameraController`.
- 🎨 **Customization**: Customize messages, overlays, and detection parameters.
- 🔄 **Continuous Workflow**: Designed for scenarios where you need to capture -> process (e.g., send to server) -> resume capture without closing the camera.

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

### Basic Usage

Simply wrap the `SmartFaceCamera` widget and handle the `onCapture` callback.

```dart
import 'package:face_detection_camera/face_detection_camera.dart';

SmartFaceCamera(
  autoCapture: true,
  captureCountdownDuration: 3000, // 3 seconds stable before capture
  onCapture: (File image) {
    print('Captured image path: ${image.path}');
  },
  messageBuilder: (context, state) {
    if (state == FaceCameraState.searching) {
      return Text('Please look at the camera');
    }
    return null; // Use default messages
  },
)
```

### Advanced Usage: Server Processing Loop

For use cases where you need to capture an image, pause the camera to send it to a server, and then resume looking for a face based on the result:

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
        onCapture: (File image) async {
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
|Or|---|---|---|
| `onCapture` | `Function(File)` | Callback when an image is captured. | Required |
| `controller` | `FaceCameraController?` | Controller to manage state programmatically. | `null` |
| `autoCapture` | `bool` | Whether to automatically capture when stable. | `true` |
| `captureCountdownDuration` | `int` | Duration in ms face must be stable. | `3000` |
| `showControls` | `bool` | Show switch camera button. | `false` |
| `messageBuilder` | `Widget Function?` | Custom builder for status messages. | `null` |
| `resolutionPreset` | `ResolutionPreset` | Camera resolution. | `ResolutionPreset.high` |

### FaceCameraController

| Method | Description |
|---|---|
| `initialize()` | Initializes camera and face detector. |
| `pause()` | Pauses stability check and countdown (camera feed continues). |
| `resume()` | Resumes stability check and auto-capture logic. |
| `capture()` | Manually trigger a capture. |
| `switchCamera()` | Switch between front and back cameras. |
| `dispose()` | Clean up resources. |
