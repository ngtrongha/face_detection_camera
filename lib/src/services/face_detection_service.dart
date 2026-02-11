import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import '../utils/camera_image_converter.dart';

/// Service to handle face detection using Google ML Kit.
/// Dịch vụ xử lý phát hiện khuôn mặt bằng Google ML Kit.
class FaceDetectionService {
  FaceDetector? _faceDetector;

  /// Whether to enable face contours detection.
  /// Có bật phát hiện đường nét khuôn mặt hay không.
  final bool enableContours;

  /// Whether to enable face classification (smile, eyes open).
  /// Có bật phân loại khuôn mặt (cười, mở mắt) hay không.
  final bool enableClassification;

  /// Minimum face size to detect (as a fraction of image width).
  /// Kích thước khuôn mặt tối thiểu để phát hiện (tỉ lệ so với chiều rộng hình ảnh).
  final double minFaceSize;

  /// Detection performance mode.
  /// Chế độ hiệu suất phát hiện.
  final FaceDetectorMode performanceMode;

  FaceDetectionService({
    this.enableContours = false,
    this.enableClassification = false,
    this.minFaceSize = 0.15,
    this.performanceMode = FaceDetectorMode.fast,
  }) {
    _initDetector();
  }

  void _initDetector() {
    final options = FaceDetectorOptions(
      performanceMode: performanceMode,
      enableContours: enableContours,
      enableClassification: enableClassification,
      enableTracking: true, // Required for anti-spoofing and stability
      minFaceSize: minFaceSize,
    );
    _faceDetector = FaceDetector(options: options);
  }

  /// Processes a camera image and returns a list of detected faces.
  /// Xử lý hình ảnh từ camera và trả về danh sách các khuôn mặt được phát hiện.
  Future<List<Face>> processImage(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (_faceDetector == null) return [];

    final rotation = rotationIntToImageRotation(camera.sensorOrientation);
    final inputImage = inputImageFromCameraImage(
      image: image,
      camera: camera,
      rotation: rotation,
    );

    if (inputImage == null) return [];

    return await _faceDetector!.processImage(inputImage);
  }

  /// Disposes the face detector and releases resources.
  /// Giải phóng bộ phát hiện khuôn mặt và các tài nguyên.
  void dispose() {
    _faceDetector?.close();
  }
}
