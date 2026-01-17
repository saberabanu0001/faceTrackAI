import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;

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
  double _threshold = 0.6;
  double? _similarityScore;
  bool? _isSamePerson;
  bool _useDarkTheme = true;
  
  // Match info for bounding boxes
  Map<String, dynamic>? _matchInfo;

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
      request.fields['threshold'] = _threshold.toString();

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
        final matchInfo = data['match_info'] as Map<String, dynamic>?;

        // Update state with results
        if (mounted) {
          setState(() {
            _similarityScore = similarity;
            _isSamePerson = isSame;
            _matchInfo = matchInfo;
          });
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
      String errorTitle = 'Error';
      IconData errorIcon = Icons.error;
      
      String errorStr = e.toString();
      
      // Handle connection errors
      if (errorStr.contains('SocketException') || 
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('Connection refused') ||
          errorStr.contains('timeout')) {
        errorTitle = 'Connection Error';
        errorMessage = 'Cannot connect to backend server.\n\n'
            'Please start the backend server:\n'
            '1. Open terminal in project root\n'
            '2. Run: ./start_backend.sh\n'
            '   (or: uvicorn backend.main:app --reload --host 0.0.0.0)\n'
            '3. Make sure it\'s running on port 8000';
      }
      // Handle "No face detected" errors
      else if (errorStr.contains('No face detected')) {
        errorTitle = 'No Face Detected';
        errorIcon = Icons.face;
        errorMessage = 'Could not detect a face in one of the images.\n\n'
            'Please make sure:\n'
            '• The image shows a clear, front-facing face\n'
            '• The face is not too small or too large\n'
            '• The image has good lighting\n'
            '• The face is not at an extreme angle\n'
            '• Try using a different image';
      }
      // Handle other face recognition errors
      else if (errorStr.contains('face') || errorStr.contains('Face')) {
        errorTitle = 'Face Recognition Error';
        errorMessage = errorStr
            .replaceAll('Exception: ', '')
            .replaceAll('Error during face comparison: ', '')
            .replaceAll('Error: ', '');
      }
      // Handle other errors
      else {
        // Clean up the error message
        errorMessage = errorStr
            .replaceAll('Exception: ', '')
            .replaceAll('Error: ', '');
        
        // If it's a server error, show a cleaner message
        if (errorStr.contains('Server error:')) {
          errorTitle = 'Server Error';
        }
      }
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(errorIcon, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(errorTitle)),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                errorMessage,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
              if (errorStr.contains('SocketException') || 
                  errorStr.contains('Failed host lookup') ||
                  errorStr.contains('Connection refused'))
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

  void clearImage1() {
    setState(() {
      image1 = null;
      _similarityScore = null;
      _isSamePerson = null;
      _matchInfo = null;
    });
  }

  void clearImage2() {
    setState(() {
      image2 = null;
      _similarityScore = null;
      _isSamePerson = null;
      _matchInfo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _useDarkTheme 
        ? const Color(0xFF0A0E27) 
        : Colors.white;
    final gradientColors = _useDarkTheme
        ? [const Color(0xFF0A0E27), const Color(0xFF1A1F3A)]
        : [Colors.white, const Color(0xFFF5F5F5)];
    final textColor = _useDarkTheme ? Colors.white : Colors.black87;
    final lightTextColor = _useDarkTheme ? Colors.white70 : Colors.black54;
    final accentColor = const Color(0xFF4A9EFF);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header with icon and title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.fingerprint,
                      size: 32,
                      color: accentColor,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Face Recognition',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload two face images to verify if they belong to the same person using advanced biometric analysis.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: lightTextColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Image comparison section
                Row(
                  children: [
                    // Image 1
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'IMAGE 1(multiple)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: lightTextColor,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: pickImage1,
                            child: Container(
                              height: 180,
                              decoration: BoxDecoration(
                                color: _useDarkTheme 
                                    ? const Color(0xFF1A1F3A) 
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: image1 != null 
                                      ? accentColor 
                                      : Colors.grey.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: image1 != null
                                  ? Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.file(
                                            image1!,
                                            width: double.infinity,
                                            height: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: clearImage1,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Icon(
                                      Icons.add_photo_alternate,
                                      size: 48,
                                      color: lightTextColor,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // VS Icon
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Image 2
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'IMAGE 2',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: lightTextColor,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: pickImage2,
                            child: Container(
                              height: 180,
                              decoration: BoxDecoration(
                                color: _useDarkTheme 
                                    ? const Color(0xFF1A1F3A) 
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: image2 != null 
                                      ? accentColor 
                                      : Colors.grey.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: image2 != null
                                  ? Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.file(
                                            image2!,
                                            width: double.infinity,
                                            height: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: clearImage2,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Icon(
                                      Icons.add_photo_alternate,
                                      size: 48,
                                      color: lightTextColor,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Similarity Threshold Slider
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SIMILARITY THRESHOLD',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: lightTextColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          _threshold.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        Slider(
                          value: _threshold,
                          min: 0.3,
                          max: 0.9,
                          divisions: 60,
                          activeColor: accentColor,
                          inactiveColor: Colors.grey.withOpacity(0.3),
                          onChanged: (value) {
                            setState(() {
                              _threshold = value;
                              _similarityScore = null;
                              _isSamePerson = null;
                            });
                          },
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 20,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Lenient',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: lightTextColor,
                                ),
                              ),
                              Text(
                                'Normal',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: lightTextColor,
                                ),
                              ),
                              Text(
                                'Strict',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: lightTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Compare Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (image1 != null && image2 != null && !_isComparing)
                        ? compareFaces
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: _isComparing
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Comparing...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.refresh,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'COMPARE FACES',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                // Results Section
                if (_similarityScore != null) ...[
                  const SizedBox(height: 32),
                  // Similarity Score
                  Column(
                    children: [
                      Text(
                        'SIMILARITY SCORE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: lightTextColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${(_similarityScore! * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: _similarityScore! >= _threshold 
                                  ? Colors.green 
                                  : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _similarityScore! >= _threshold 
                                ? Icons.arrow_upward 
                                : Icons.arrow_downward,
                            color: _similarityScore! >= _threshold 
                                ? Colors.green 
                                : Colors.red,
                            size: 24,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Result Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _isSamePerson! 
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isSamePerson! ? Colors.green : Colors.red,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isSamePerson! ? Icons.check_circle : Icons.cancel,
                          color: _isSamePerson! ? Colors.green : Colors.red,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isSamePerson! ? 'SAME PERSON' : 'DIFFERENT PERSON',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isSamePerson! ? Colors.green : Colors.red,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Third Section: Show matched face with bounding box (if multiple faces)
                  if (_matchInfo != null && 
                      (_matchInfo!['multiple_faces_image1'] == true || 
                       _matchInfo!['multiple_faces_image2'] == true)) ...[
                    const SizedBox(height: 32),
                    Text(
                      'MATCHED PERSON',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: lightTextColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildImageWithBoundingBox(),
                  ],
                ],
                const SizedBox(height: 20),
                // Theme Toggle
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _useDarkTheme = !_useDarkTheme;
                    });
                  },
                  icon: Icon(
                    _useDarkTheme ? Icons.light_mode : Icons.dark_mode,
                    color: lightTextColor,
                  ),
                  label: Text(
                    _useDarkTheme ? 'Light Mode' : 'Dark Mode',
                    style: TextStyle(color: lightTextColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageWithBoundingBox() {
    print('🔍 _buildImageWithBoundingBox called');
    print('🔍 _matchInfo: $_matchInfo');
    
    // Determine which image has multiple faces
    bool image1HasMultiple = _matchInfo!['multiple_faces_image1'] == true;
    bool image2HasMultiple = _matchInfo!['multiple_faces_image2'] == true;
    
    print('🔍 image1HasMultiple: $image1HasMultiple, image2HasMultiple: $image2HasMultiple');
    print('🔍 image1: $image1, image2: $image2');
    
    // Show the image with multiple faces, or image1 if both have multiple
    File? targetImage;
    Map<String, dynamic>? location;
    const accentColor = Color(0xFF4A9EFF);
    
    if (image1HasMultiple && image1 != null) {
      targetImage = image1;
      location = _matchInfo!['face1_location'] as Map<String, dynamic>?;
      print('🔍 Using image1 with face1_location: $location');
    } else if (image2HasMultiple && image2 != null) {
      targetImage = image2;
      location = _matchInfo!['face2_location'] as Map<String, dynamic>?;
      print('🔍 Using image2 with face2_location: $location');
    } else {
      // Fallback: show image1 if available
      targetImage = image1;
      location = _matchInfo!['face1_location'] as Map<String, dynamic>?;
      print('🔍 Fallback: Using image1 with face1_location: $location');
    }
    
    if (targetImage == null || location == null) {
      print('❌ targetImage or location is null! targetImage: $targetImage, location: $location');
      return const SizedBox.shrink();
    }
    
    print('✅ Building bounding box widget');
    
    // Extract to non-nullable variables after null check
    final nonNullTargetImage = targetImage!;
    final nonNullLocation = location!;
    
    return FutureBuilder<Size>(
      future: _getImageSize(nonNullTargetImage),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('⏳ Loading image size...');
          return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        }
        
        if (snapshot.hasError) {
          print('❌ Error loading image: ${snapshot.error}');
          return const SizedBox(height: 200, child: Center(child: Text('Error loading image')));
        }
        
        if (!snapshot.hasData) {
          print('❌ No image size data');
          return const SizedBox(height: 200, child: Center(child: Text('No image data')));
        }
        
        final originalImageSize = snapshot.data!;
        print('✅ Image size loaded: ${originalImageSize.width}x${originalImageSize.height}');
        final originalTop = (nonNullLocation['top'] as num).toDouble();
        final originalRight = (nonNullLocation['right'] as num).toDouble();
        final originalBottom = (nonNullLocation['bottom'] as num).toDouble();
        final originalLeft = (nonNullLocation['left'] as num).toDouble();
        
        // Ultra-simple approach: Use InteractiveViewer to show image
        // and overlay a simple colored rectangle
        final totalFaces = _matchInfo!['total_faces_image1'] as int? ?? 
                          _matchInfo!['total_faces_image2'] as int? ?? 1;
        
        return Column(
          children: [
            // Image container with bounding box overlay
            Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accentColor,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _BoundingBoxImage(
                  imageFile: nonNullTargetImage,
                  originalImageSize: originalImageSize,
                  bboxTop: originalTop,
                  bboxLeft: originalLeft,
                  bboxBottom: originalBottom,
                  bboxRight: originalRight,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Info badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.green,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.face,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    totalFaces > 1
                        ? 'Matched: Face #1 of $totalFaces detected faces'
                        : 'Face matched successfully',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Size> _getImageSize(File imageFile) async {
    final image = await decodeImageFromList(await imageFile.readAsBytes());
    return Size(image.width.toDouble(), image.height.toDouble());
  }
}

class SimpleBoundingBoxPainter extends CustomPainter {
  final Size imageSize;
  final double bboxTop;
  final double bboxLeft;
  final double bboxBottom;
  final double bboxRight;
  final Size containerSize;

  SimpleBoundingBoxPainter({
    required this.imageSize,
    required this.bboxTop,
    required this.bboxLeft,
    required this.bboxBottom,
    required this.bboxRight,
    required this.containerSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate how image is displayed (BoxFit.contain)
    final imageAspectRatio = imageSize.width / imageSize.height;
    final containerAspectRatio = containerSize.width / containerSize.height;
    
    double displayedWidth;
    double displayedHeight;
    double offsetX = 0;
    double offsetY = 0;
    
    if (imageAspectRatio > containerAspectRatio) {
      displayedWidth = containerSize.width;
      displayedHeight = containerSize.width / imageAspectRatio;
      offsetY = (containerSize.height - displayedHeight) / 2;
    } else {
      displayedHeight = containerSize.height;
      displayedWidth = containerSize.height * imageAspectRatio;
      offsetX = (containerSize.width - displayedWidth) / 2;
    }
    
    // Scale factors
    final scaleX = displayedWidth / imageSize.width;
    final scaleY = displayedHeight / imageSize.height;
    
    // Scale coordinates
    final scaledLeft = bboxLeft * scaleX + offsetX;
    final scaledTop = bboxTop * scaleY + offsetY;
    final scaledRight = bboxRight * scaleX + offsetX;
    final scaledBottom = bboxBottom * scaleY + offsetY;
    
    // Draw bounding box with green border
    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    
    final rect = Rect.fromLTRB(
      scaledLeft,
      scaledTop,
      scaledRight,
      scaledBottom,
    );
    
    // Draw main border
    canvas.drawRect(rect, paint);
    
    // Draw corner markers for better visibility
    final cornerLength = 20.0;
    final cornerPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;
    
    // Top-left corner
    canvas.drawLine(
      Offset(scaledLeft, scaledTop),
      Offset(scaledLeft + cornerLength, scaledTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scaledLeft, scaledTop),
      Offset(scaledLeft, scaledTop + cornerLength),
      cornerPaint,
    );
    
    // Top-right corner
    canvas.drawLine(
      Offset(scaledRight, scaledTop),
      Offset(scaledRight - cornerLength, scaledTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scaledRight, scaledTop),
      Offset(scaledRight, scaledTop + cornerLength),
      cornerPaint,
    );
    
    // Bottom-left corner
    canvas.drawLine(
      Offset(scaledLeft, scaledBottom),
      Offset(scaledLeft + cornerLength, scaledBottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scaledLeft, scaledBottom),
      Offset(scaledLeft, scaledBottom - cornerLength),
      cornerPaint,
    );
    
    // Bottom-right corner
    canvas.drawLine(
      Offset(scaledRight, scaledBottom),
      Offset(scaledRight - cornerLength, scaledBottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scaledRight, scaledBottom),
      Offset(scaledRight, scaledBottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Separate widget for bounding box image - simpler approach
class _BoundingBoxImage extends StatelessWidget {
  final File imageFile;
  final Size originalImageSize;
  final double bboxTop;
  final double bboxLeft;
  final double bboxBottom;
  final double bboxRight;

  const _BoundingBoxImage({
    required this.imageFile,
    required this.originalImageSize,
    required this.bboxTop,
    required this.bboxLeft,
    required this.bboxBottom,
    required this.bboxRight,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth;
        final containerHeight = constraints.maxHeight;
        
        // Calculate displayed image size (BoxFit.contain)
        final imageAspectRatio = originalImageSize.width / originalImageSize.height;
        final containerAspectRatio = containerWidth / containerHeight;
        
        double displayedWidth;
        double displayedHeight;
        double offsetX = 0;
        double offsetY = 0;
        
        if (imageAspectRatio > containerAspectRatio) {
          displayedWidth = containerWidth;
          displayedHeight = containerWidth / imageAspectRatio;
          offsetY = (containerHeight - displayedHeight) / 2;
        } else {
          displayedHeight = containerHeight;
          displayedWidth = containerHeight * imageAspectRatio;
          offsetX = (containerWidth - displayedWidth) / 2;
        }
        
        // Scale factors
        final scaleX = displayedWidth / originalImageSize.width;
        final scaleY = displayedHeight / originalImageSize.height;
        
        // Scale coordinates
        final scaledLeft = bboxLeft * scaleX + offsetX;
        final scaledTop = bboxTop * scaleY + offsetY;
        final scaledRight = bboxRight * scaleX + offsetX;
        final scaledBottom = bboxBottom * scaleY + offsetY;
        
        // Debug
        print('🎯 BBOX CALC:');
        print('   Original: ${originalImageSize.width}x${originalImageSize.height}');
        print('   Bbox: top=$bboxTop, left=$bboxLeft, bottom=$bboxBottom, right=$bboxRight');
        print('   Displayed: ${displayedWidth}x${displayedHeight}');
        print('   Scale: $scaleX x $scaleY');
        print('   Offset: $offsetX, $offsetY');
        print('   Scaled: left=$scaledLeft, top=$scaledTop, right=$scaledRight, bottom=$scaledBottom');
        print('   Size: ${scaledRight - scaledLeft} x ${scaledBottom - scaledTop}');
        
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Image - centered with BoxFit.contain
            Center(
              child: SizedBox(
                width: displayedWidth,
                height: displayedHeight,
                child: Image.file(
                  imageFile,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Bounding box overlay
            if (scaledRight > scaledLeft && scaledBottom > scaledTop && 
                scaledLeft >= 0 && scaledTop >= 0 &&
                scaledRight <= containerWidth && scaledBottom <= containerHeight)
              Positioned(
                left: scaledLeft,
                top: scaledTop,
                child: Container(
                  width: scaledRight - scaledLeft,
                  height: scaledBottom - scaledTop,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.green,
                      width: 5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.8),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
