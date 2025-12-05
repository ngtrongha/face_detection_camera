import 'package:face_detection_camera/face_detection_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const HomeScreen());
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Uint8List? _capturedImage;
  late FaceCameraController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FaceCameraController(
      autoCapture: true,
      captureCountdownDuration: 3000,
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
      appBar: AppBar(title: const Text('Face Detection Camera Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_capturedImage != null) ...[
              Image.memory(_capturedImage!, height: 300),
              const SizedBox(height: 20),
              const Text('Last Captured Face!'),
            ] else
              const Text('No image captured yet'),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SmartFaceCamera(
                      controller: _controller,
                      autoCapture: true,
                      vignettePaddingFactor: 0.8,
                      onCapture: (Uint8List image) async {
                        // Pause immediately to process
                        _controller.pause();

                        setState(() {
                          _capturedImage = image;
                        });

                        // Simulate server processing
                        await showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Processing...'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Sending image to server...\nCamera is paused (by user) but detecting.',
                                ),
                                const SizedBox(height: 10),
                                Image.memory(image, height: 150),
                                const SizedBox(height: 10),
                                const LinearProgressIndicator(),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                },
                                child: const Text('Complete & Resume'),
                              ),
                            ],
                          ),
                        );

                        // Resume camera for next capture
                        _controller.resume();
                      },
                      messageBuilder: (context, state) {
                        if (state == FaceCameraState.searching) {
                          return const Text(
                            'Finding face...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                        if (state == FaceCameraState.captured) {
                          return const Text(
                            'Processing...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                        return null; // Use default
                      },
                    ),
                  ),
                );
              },
              child: const Text('Open Camera Loop'),
            ),
          ],
        ),
      ),
    );
  }
}
