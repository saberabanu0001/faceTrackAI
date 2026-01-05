import 'dart:io';
import 'dart:convert';
import 'dart:async';

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
    print('Compare faces button clicked');
    
    if (image1 == null || image2 == null) {
      print('Images are null: image1=$image1, image2=$image2');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both images first')),
      );
      return;
    }

    print('Starting face comparison...');
    print('Image1 path: ${image1!.path}');
    print('Image2 path: ${image2!.path}');
    print('Backend URL: $backendUrl/compare');

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

      // Send request with timeout
      print('Sending request to backend...');
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Is the backend running at $backendUrl?');
        },
      );
      print('Response received, status: ${streamedResponse.statusCode}');
      var response = await http.Response.fromStream(streamedResponse);
      print('Response body: ${response.body}');

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
        // Try to parse error message from backend
        String errorMsg = 'Server error: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData.containsKey('detail')) {
            errorMsg = errorData['detail'] as String;
          } else {
            errorMsg = response.body;
          }
        } catch (e) {
          errorMsg = 'Server error: ${response.statusCode}\n${response.body}';
        }
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      print('Error in compareFaces: $e');
      print('Stack trace: $stackTrace');
      
      String errorMessage = 'Error comparing faces';
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('timeout')) {
        errorMessage = 'Cannot connect to backend server.\n\n'
            'Please start the backend server:\n'
            '1. Open terminal in project root\n'
            '2. Run: uvicorn backend.main:app --reload --host 0.0.0.0\n'
            '3. Make sure it\'s running on port 8000';
      } else {
        errorMessage = 'Error: $e';
      }
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: SingleChildScrollView(
              child: Text(errorMessage),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
              if (e.toString().contains('SocketException') || 
                  e.toString().contains('Failed host lookup') ||
                  e.toString().contains('Connection refused'))
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Backend URL: http://10.0.2.2:8000'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                  child: const Text('Show URL'),
                ),
            ],
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
                  ? () {
                      print('Button pressed - image1: ${image1 != null}, image2: ${image2 != null}, isComparing: $_isComparing');
                      compareFaces();
                    }
                  : () {
                      print('Button disabled - image1: ${image1 != null}, image2: ${image2 != null}, isComparing: $_isComparing');
                      if (image1 == null || image2 == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select both images first'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
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
