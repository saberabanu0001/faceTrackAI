import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';


void main() {
  runApp(const FaceRecognitionApp());
}

class FaceRecognitionApp extends StatelessWidget {
  const FaceRecognitionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Face Recognition',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
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
  final ImagePicker _picker = ImagePicker();
  
  // Backend URL - for Android emulator use 10.0.2.2, for iOS simulator use localhost
  // Change this to your actual backend URL if different
  static const String backendUrl = 'http://10.0.2.2:8000'; // Android emulator
  // static const String backendUrl = 'http://localhost:8000'; // iOS simulator or physical device

  File? image1;
  File? image2;
  bool _isComparing = false;

  Future<void> _showImageSourceDialog(Function(ImageSource) onSourceSelected) async {
    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  onSourceSelected(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  onSourceSelected(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> pickImage1() async {
    await _showImageSourceDialog((ImageSource source) async {
      try {
        final XFile? picked = await _picker.pickImage(
          source: source,
          imageQuality: 100,
        );
        if (picked != null) {
          setState(() {
            image1 = File(picked.path);
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error picking image: $e')),
          );
        }
      }
    });
  }

  Future<void> pickImage2() async {
    await _showImageSourceDialog((ImageSource source) async {
      try {
        final XFile? picked = await _picker.pickImage(
          source: source,
          imageQuality: 100,
        );
        if (picked != null) {
          setState(() {
            image2 = File(picked.path);
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error picking image: $e')),
          );
        }
      }
    });
  }

  Future<void> compareFaces() async {
    if (image1 == null || image2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both images first')),
      );
      return;
    }

    setState(() {
      _isComparing = true;
    });

    try {
      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendUrl/compare'),
      );

      // Add images
      request.files.add(
        await http.MultipartFile.fromPath(
          'img1',
          image1!.path,
          filename: 'image1.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );
      request.files.add(
        await http.MultipartFile.fromPath(
          'img2',
          image2!.path,
          filename: 'image2.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      // Add threshold
      request.fields['threshold'] = '0.6';

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final similarity = data['similarity'] as double;
        final isSame = data['is_same'] as bool;

        // Show results dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Comparison Result'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Similarity Score: ${(similarity * 100).toStringAsFixed(2)}%',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSame ? Icons.check_circle : Icons.cancel,
                        color: isSame ? Colors.green : Colors.red,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isSame ? 'SAME PERSON' : 'DIFFERENT PERSON',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isSame ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error comparing faces: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isComparing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Face Recognition"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: pickImage1,
              child: const Text("Pick Image 1"),
            ),
            const SizedBox(height: 8),
            image1 != null
                ? Image.file(image1!, height: 120)
                : const Text("No image selected"),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: pickImage2,
              child: const Text("Pick Image 2"),
            ),
            const SizedBox(height: 8),
            image2 != null
                ? Image.file(image2!, height: 120)
                : const Text("No image selected"),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: (image1 != null && image2 != null && !_isComparing)
                  ? compareFaces
                  : null,
              child: _isComparing
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text("Comparing..."),
                      ],
                    )
                  : const Text("Compare Faces"),
            ),
          ],
          
        ),
      ),
    );
  }
}
