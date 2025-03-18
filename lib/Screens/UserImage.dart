import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class UserImage extends StatefulWidget {
  const UserImage({super.key});

  @override
  State<UserImage> createState() => _UserImageState();
}

class _UserImageState extends State<UserImage> {
  late CameraController _cameraController;
  Future<void>? _initializeControllerFuture;
  XFile? _capturedImage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      final frontCamera = cameras.firstWhere((camera) => camera.lensDirection == CameraLensDirection.front);

      // Initialize the camera controller
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
      );

      _initializeControllerFuture = _cameraController.initialize();
      setState(() {});
    } catch (e) {
      // Handle errors gracefully
      debugPrint('Error initializing camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize camera: $e')),
      );
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      if (_initializeControllerFuture == null) return;

      await _initializeControllerFuture;

      // Capture the photo
      final image = await _cameraController.takePicture();

      // Set the captured image to display it
      setState(() {
        _capturedImage = image;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking photo: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Take Photo',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: _capturedImage == null
          ? (_initializeControllerFuture == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // Display the camera preview
            return Center(
                child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                   child: CameraPreview(_cameraController)));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            // Show a loading spinner while waiting
            return const Center(child: CircularProgressIndicator());
          }
        },
      ))
          : Image.file(
        File(_capturedImage!.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () {
              if (_capturedImage == null) {
                _takePhoto();
              } else {
                // Reset state to retake the photo
                setState(() {
                  _capturedImage = null;
                  _initializeCamera();
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _capturedImage == null ? 'Take Photo' : 'Try Again',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (_capturedImage != null)
            const SizedBox(height: 10), // Spacing between buttons
          if (_capturedImage != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, _capturedImage!.path);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                ),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
        ],
       ),
      ),
    );
  }
}
