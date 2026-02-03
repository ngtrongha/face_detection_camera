import 'package:flutter_test/flutter_test.dart';
import 'package:face_detection_camera/face_detection_camera.dart';

void main() {
  group('FaceCameraController', () {
    group('Configuration', () {
      test('should have default values', () {
        final controller = FaceCameraController();

        expect(controller.autoCapture, true);
        expect(controller.captureCountdownDuration, 3000);
        expect(controller.resolutionPreset, ResolutionPreset.high);
        expect(controller.enableAudio, true);
        expect(
          controller.initialCameraLensDirection,
          CameraLensDirection.front,
        );
        expect(controller.imageFormat, CameraImageFormat.jpeg);
        expect(controller.enableImageProcessing, true);
        expect(controller.maxYawDegrees, 12.0);
        expect(controller.maxRollDegrees, 12.0);
        expect(controller.maxPitchDegrees, 12.0);
        expect(controller.jpegQuality, 90);
        expect(controller.cropToFace, false);
        expect(controller.faceCropPadding, 1.5);
        expect(controller.enableContours, false);
        expect(controller.enableClassification, false);
        expect(controller.initialFlashMode, FlashMode.off);
        expect(controller.lockOrientation, true);
        // Phase 2 defaults
        expect(controller.detectMultipleFaces, false);
        expect(controller.maxFaces, 5);
        expect(controller.minQualityScore, 0.0);
        expect(controller.enableZoom, false);
        expect(controller.minZoom, 1.0);
        expect(controller.maxZoom, 5.0);
        expect(controller.enableCaptureSound, false);
        expect(controller.maxRetryAttempts, 3);
      });

      test('should accept custom values', () {
        final controller = FaceCameraController(
          autoCapture: false,
          captureCountdownDuration: 5000,
          resolutionPreset: ResolutionPreset.medium,
          enableAudio: false,
          initialCameraLensDirection: CameraLensDirection.back,
          imageFormat: CameraImageFormat.png,
          enableImageProcessing: false,
          maxYawDegrees: 15.0,
          maxRollDegrees: 10.0,
          maxPitchDegrees: 8.0,
          jpegQuality: 80,
          cropToFace: true,
          faceCropPadding: 2.0,
          enableContours: true,
          enableClassification: true,
          initialFlashMode: FlashMode.torch,
          lockOrientation: false,
          detectMultipleFaces: true,
          maxFaces: 10,
          minQualityScore: 0.5,
          enableZoom: true,
          minZoom: 0.5,
          maxZoom: 10.0,
          enableCaptureSound: true,
          maxRetryAttempts: 5,
        );

        expect(controller.autoCapture, false);
        expect(controller.captureCountdownDuration, 5000);
        expect(controller.resolutionPreset, ResolutionPreset.medium);
        expect(controller.detectMultipleFaces, true);
        expect(controller.maxFaces, 10);
        expect(controller.minQualityScore, 0.5);
        expect(controller.enableZoom, true);
        expect(controller.maxZoom, 10.0);
        expect(controller.enableCaptureSound, true);
        expect(controller.maxRetryAttempts, 5);
      });
    });

    group('State', () {
      test('should start in loading state', () {
        final controller = FaceCameraController();
        expect(controller.state, FaceCameraState.loading);
      });

      test('should have null captured image initially', () {
        final controller = FaceCameraController();
        expect(controller.capturedImage, isNull);
      });
    });

    group('ValueNotifiers', () {
      test('should initialize flashMode with initialFlashMode', () {
        final controller = FaceCameraController(
          initialFlashMode: FlashMode.torch,
        );
        expect(controller.flashMode.value, FlashMode.torch);
      });

      test('should initialize facingForward to true', () {
        final controller = FaceCameraController();
        expect(controller.facingForward.value, true);
      });

      test('should initialize remainingSeconds to 0', () {
        final controller = FaceCameraController();
        expect(controller.remainingSeconds.value, 0);
      });

      test('should initialize detectedFace to null', () {
        final controller = FaceCameraController();
        expect(controller.detectedFace.value, isNull);
      });

      test('should initialize zoomLevel to 1.0', () {
        final controller = FaceCameraController();
        expect(controller.zoomLevel.value, 1.0);
      });

      test('should initialize detectedFaces to empty list', () {
        final controller = FaceCameraController();
        expect(controller.detectedFaces.value, isEmpty);
      });

      test('should initialize faceQuality to null', () {
        final controller = FaceCameraController();
        expect(controller.faceQuality.value, isNull);
      });
    });

    group('Error Callback', () {
      test('should accept onError callback', () {
        FaceCameraError? receivedError;
        String? receivedMessage;

        final controller = FaceCameraController(
          onError: (error, message) {
            receivedError = error;
            receivedMessage = message;
          },
        );

        controller.onError?.call(FaceCameraError.noCamera, 'No camera found');

        expect(receivedError, FaceCameraError.noCamera);
        expect(receivedMessage, 'No camera found');
      });
    });
  });

  group('FaceCameraState', () {
    test('should have all expected states', () {
      expect(FaceCameraState.values, contains(FaceCameraState.loading));
      expect(
        FaceCameraState.values,
        contains(FaceCameraState.permissionDenied),
      );
      expect(FaceCameraState.values, contains(FaceCameraState.searching));
      expect(FaceCameraState.values, contains(FaceCameraState.detected));
      expect(FaceCameraState.values, contains(FaceCameraState.stable));
      expect(FaceCameraState.values, contains(FaceCameraState.capturing));
      expect(FaceCameraState.values, contains(FaceCameraState.captured));
      expect(FaceCameraState.values, contains(FaceCameraState.error));
    });
  });

  group('FaceCameraError', () {
    test('should have all expected error types', () {
      expect(
        FaceCameraError.values,
        contains(FaceCameraError.permissionDenied),
      );
      expect(
        FaceCameraError.values,
        contains(FaceCameraError.cameraInitFailed),
      );
      expect(FaceCameraError.values, contains(FaceCameraError.captureFailed));
      expect(
        FaceCameraError.values,
        contains(FaceCameraError.processingFailed),
      );
      expect(FaceCameraError.values, contains(FaceCameraError.noCamera));
    });
  });

  group('CameraImageFormat', () {
    test('should have jpeg and png formats', () {
      expect(CameraImageFormat.values, contains(CameraImageFormat.jpeg));
      expect(CameraImageFormat.values, contains(CameraImageFormat.png));
    });
  });

  group('FaceQuality', () {
    test('should calculate overall score correctly', () {
      const quality = FaceQuality(
        brightness: 0.8,
        sharpness: 0.6,
        poseScore: 0.9,
      );

      expect(quality.overallScore, closeTo(0.767, 0.01));
    });

    test('should have correct string representation', () {
      const quality = FaceQuality(
        brightness: 0.5,
        sharpness: 0.5,
        poseScore: 0.5,
      );

      expect(quality.toString(), contains('brightness: 0.50'));
      expect(quality.toString(), contains('sharpness: 0.50'));
      expect(quality.toString(), contains('poseScore: 0.50'));
      expect(quality.toString(), contains('overall: 0.50'));
    });
  });
}
