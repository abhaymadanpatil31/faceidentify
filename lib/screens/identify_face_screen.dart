import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../database/database_helper.dart';
import '../models/person_model.dart';
import '../services/face_recognition_service.dart';
import '../services/facenet_service.dart';

class IdentifyFaceScreen extends StatefulWidget {
  const IdentifyFaceScreen({super.key});

  @override
  State<IdentifyFaceScreen> createState() => _IdentifyFaceScreenState();
}

class _IdentifyFaceScreenState extends State<IdentifyFaceScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;

  PersonModel? _identifiedPerson;
  double _confidence = 0;
  String? _message;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _message = 'No camera available';
        });
        return;
      }

      // Use front camera if available
      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Camera initialization failed: ${e.toString()}';
      });
    }
  }

  Future<void> _captureAndIdentify() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _identifiedPerson = null;
      _confidence = 0;
      _message = 'Analyzing face...';
    });

    try {
      // Capture image
      final XFile imageFile = await _cameraController!.takePicture();

      // Validate face
      final validationResult = await FaceRecognitionService.instance
          .validateFaceImage(imageFile.path);

      if (!validationResult.isValid) {
        setState(() {
          _message = validationResult.message;
          _isProcessing = false;
        });
        return;
      }

      // Extract features from captured image
      final faces = await FaceRecognitionService.instance.detectFaces(
        imageFile.path,
      );

      if (faces.isEmpty) {
        setState(() {
          _message = 'No face detected';
          _isProcessing = false;
        });
        return;
      }

      // Extract embedding from captured image using FaceNet
      print('Extracting FaceNet embedding from captured image...');
      final capturedEmbedding = await FaceNetService.instance
          .extractFaceEmbedding(imageFile.path, faces.first);
      print('Captured embedding: ${capturedEmbedding.length} dimensions');

      // Get all registered persons
      final persons = await DatabaseHelper.instance.getAllPersons();

      if (persons.isEmpty) {
        setState(() {
          _message =
              'No registered persons found. Please register someone first.';
          _isProcessing = false;
        });
        return;
      }

      // Filter only persons with embeddings (new format)
      final personsWithEmbeddings =
          persons.where((p) => p.hasEmbedding).toList();

      if (personsWithEmbeddings.isEmpty) {
        setState(() {
          _message = 'No persons with FaceNet embeddings. Please re-register.';
          _isProcessing = false;
        });
        return;
      }

      // Find best match using cosine similarity
      PersonModel? bestMatch;
      double bestSimilarity = 0;

      for (final person in personsWithEmbeddings) {
        final registeredEmbedding = person.embedding!;
        final similarity = FaceNetService.instance.calculateSimilarity(
          capturedEmbedding,
          registeredEmbedding,
        );

        print(
            'Comparing with ${person.name}: ${similarity.toStringAsFixed(2)}%');

        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestMatch = person;
        }
      }

      // Threshold: 70% for FaceNet (much better than 35% with ML Kit!)
      const threshold = 70.0;

      setState(() {
        if (bestMatch != null && bestSimilarity >= threshold) {
          _identifiedPerson = bestMatch;
          _confidence = bestSimilarity;
          _message = 'Match found!';
          print(
              '✅ Match: ${bestMatch.name} (${bestSimilarity.toStringAsFixed(1)}%)');
        } else {
          if (bestMatch != null) {
            print(
                '❌ Best match: ${bestMatch.name} (${bestSimilarity.toStringAsFixed(1)}%) - below threshold');
          }
          _message =
              'No matching face found (threshold: ${threshold.toStringAsFixed(0)}%)';
        }
        _isProcessing = false;
      });

      // Clean up temporary image
      try {
        await File(imageFile.path).delete();
      } catch (e) {
        // Ignore cleanup errors
      }
    } catch (e) {
      setState(() {
        _message = 'Error: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  void _resetIdentification() {
    setState(() {
      _identifiedPerson = null;
      _confidence = 0;
      _message = null;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Identify Face',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF6C63FF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Camera Preview
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _buildCameraPreview(),
              ),
            ),
          ),

          // Results Section
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: _buildResultsSection(),
            ),
          ),
        ],
      ),
      floatingActionButton: _isInitialized && !_isProcessing
          ? FloatingActionButton.extended(
              onPressed: _identifiedPerson == null
                  ? _captureAndIdentify
                  : _resetIdentification,
              backgroundColor: const Color(0xFF6C63FF),
              icon: Icon(
                _identifiedPerson == null
                    ? Icons.face_retouching_natural
                    : Icons.refresh,
                color: Colors.white,
              ),
              label: Text(
                _identifiedPerson == null ? 'Identify' : 'Scan Again',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCameraPreview() {
    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
            ),
            const SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Center(
        child: Text(
          _message ?? 'Camera not available',
          style: GoogleFonts.poppins(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),

        // Face detection guide overlay
        if (_identifiedPerson == null && !_isProcessing)
          Center(
            child: Container(
              width: 250,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(150),
              ),
            ),
          ),

        // Processing indicator
        if (_isProcessing)
          Container(
            color: Colors.black.withValues(alpha: 0.6),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Analyzing face...',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResultsSection() {
    if (_identifiedPerson != null) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Success Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 48,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Match Found!',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.green[700],
              ),
            ),

            const SizedBox(height: 24),

            // Person Details Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Profile Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_identifiedPerson!.imagePath),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildDetailRow(
                    Icons.person,
                    'Name',
                    _identifiedPerson!.name,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    Icons.fingerprint,
                    'ID',
                    _identifiedPerson!.id.substring(0, 8).toUpperCase(),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    Icons.calendar_today,
                    'Registered',
                    _formatDate(_identifiedPerson!.registeredAt),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Confidence Indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getConfidenceColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getConfidenceColor().withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified, color: _getConfidenceColor()),
                  const SizedBox(width: 8),
                  Text(
                    'Confidence: ${_confidence.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _getConfidenceColor(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // No match or initial state
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _message != null
                ? Icons.info_outline
                : Icons.face_retouching_natural,
            size: 64,
            color: _message != null
                ? (_message!.contains('No matching')
                    ? Colors.orange
                    : Colors.grey[400])
                : const Color(0xFF6C63FF).withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _message ?? 'Position your face in the frame',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (_message == null)
            Text(
              'Press "Identify" to scan',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6C63FF)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getConfidenceColor() {
    if (_confidence >= 90) return Colors.green;
    if (_confidence >= 80) return Colors.lightGreen;
    if (_confidence >= 70) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
