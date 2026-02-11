import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  CameraDescription? _currentCamera;

  CameraController? get controller => _controller;
  CameraDescription? get currentCamera => _currentCamera;
  List<CameraDescription> get cameras => _cameras;

  Future<void> initialize({
    required CameraLensDirection initialDirection,
    required ResolutionPreset resolutionPreset,
    required bool enableAudio,
    required FlashMode initialFlashMode,
    required bool lockOrientation,
    Function(CameraImage)? onImageStream,
  }) async {
    if (lockOrientation) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }

    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw Exception('No cameras available');
    }

    _currentCamera = _cameras.firstWhere(
      (c) => c.lensDirection == initialDirection,
      orElse: () => _cameras.first,
    );

    await _initController(
      resolutionPreset: resolutionPreset,
      enableAudio: enableAudio,
      initialFlashMode: initialFlashMode,
      onImageStream: onImageStream,
    );
  }

  Future<void> _initController({
    required ResolutionPreset resolutionPreset,
    required bool enableAudio,
    required FlashMode initialFlashMode,
    Function(CameraImage)? onImageStream,
  }) async {
    _controller = CameraController(
      _currentCamera!,
      resolutionPreset,
      enableAudio: enableAudio,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();
    await _controller!.setFlashMode(initialFlashMode);

    if (onImageStream != null) {
      await _controller!.startImageStream(onImageStream);
    }
  }

  Future<void> switchCamera({
    required ResolutionPreset resolutionPreset,
    required bool enableAudio,
    required FlashMode currentFlashMode,
    Function(CameraImage)? onImageStream,
  }) async {
    if (_cameras.isEmpty) return;

    final lensDirection = _currentCamera!.lensDirection;
    CameraDescription newCamera;

    if (lensDirection == CameraLensDirection.front) {
      newCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
    } else {
      newCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );
    }

    if (newCamera.lensDirection == lensDirection && _cameras.length > 1) {
      final index = _cameras.indexOf(_currentCamera!);
      newCamera = _cameras[(index + 1) % _cameras.length];
    }

    if (newCamera == _currentCamera) return;

    _currentCamera = newCamera;
    await _controller?.dispose();

    await _initController(
      resolutionPreset: resolutionPreset,
      enableAudio: enableAudio,
      initialFlashMode: currentFlashMode,
      onImageStream: onImageStream,
    );
  }

  Future<void> setFlashMode(FlashMode mode) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    await _controller!.setFlashMode(mode);
  }

  Future<void> setZoomLevel(double zoom) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    await _controller!.setZoomLevel(zoom);
  }

  Future<XFile> takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }
    return await _controller!.takePicture();
  }

  void dispose() {
    _controller?.dispose();
  }
}
