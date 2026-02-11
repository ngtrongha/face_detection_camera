import 'package:face_detection_camera/face_detection_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock orientation to portrait for camera apps typically
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Detection Camera',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Uint8List? _capturedImage;
  LivenessResult? _livenessResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Detection Camera'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview Section
            if (_capturedImage != null) ...[
              const Text(
                'Captured Image:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  _capturedImage!,
                  height: 300,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Liveness Result Section
            if (_livenessResult != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _livenessResult!.passed
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _livenessResult!.passed ? Colors.green : Colors.red,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liveness Status: ${_livenessResult!.passed ? "PASSED ✅" : "FAILED ❌"}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _livenessResult!.passed
                            ? Colors.green.shade900
                            : Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Duration: ${_livenessResult!.totalDuration.inSeconds}s',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Challenge Details:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ..._livenessResult!.challengeResults.map(
                      (r) => Text(
                        '- ${r.challenge.name}: ${r.state.name} (${r.duration.inMilliseconds}ms)',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Action Buttons
            const Text(
              'Select Camera Mode:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openNormalCamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Normal Auto Capture'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _openLivenessCamera,
              icon: const Icon(Icons.security),
              label: const Text('Liveness Detection'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blue.shade50,
              ),
            ),
            const SizedBox(height: 40),
            if (_capturedImage == null && _livenessResult == null)
              const Center(
                child: Text(
                  'No data yet.\nPlease select a mode above.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openNormalCamera() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SmartFaceCamera(
          autoCapture: true,
          showControls: true,
          showFlashButton: true,
          cropToFace: true,
          onCapture: (Uint8List image) {
            setState(() {
              _capturedImage = image;
              _livenessResult = null;
            });
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Face captured successfully!')),
            );
          },
        ),
      ),
    );
  }

  void _openLivenessCamera() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LivenessCameraWidget(
          challenges: const [
            LivenessChallengeConfig(
              challenge: LivenessChallenge.blink,
              instructionText: 'Hãy chớp mắt',
            ),
            LivenessChallengeConfig(
              challenge: LivenessChallenge.smile,
              instructionText: 'Hãy mỉm cười',
              holdDuration: Duration(seconds: 1),
            ),
            LivenessChallengeConfig(
              challenge: LivenessChallenge.turnLeft,
              instructionText: 'Hãy quay mặt sang trái',
              threshold: 25, // degrees
            ),
          ],
          onLivenessComplete: (LivenessResult result) {
            setState(() {
              _livenessResult = result;
              // If it passed, show the captured image if available
              // (Future: LivenessController could trigger capture at the end)
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}
