import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../models/person_model.dart';
import '../services/face_recognition_service.dart';
import '../services/facenet_service.dart';

class RegisterFaceScreen extends StatefulWidget {
  const RegisterFaceScreen({super.key});

  @override
  State<RegisterFaceScreen> createState() => _RegisterFaceScreenState();
}

class _RegisterFaceScreenState extends State<RegisterFaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _imagePicker = ImagePicker();

  File? _capturedImage;
  bool _isProcessing = false;
  String? _validationMessage;
  bool _isFaceValid = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _captureImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front, // Use front camera
        maxWidth: 1280, // Limit size for consistency
        maxHeight: 1280,
      );

      if (pickedFile == null) return;

      setState(() {
        _capturedImage = File(pickedFile.path);
        _isProcessing = true;
        _validationMessage = 'Validating face...';
        _isFaceValid = false;
      });

      // Validate the captured face
      final validationResult = await FaceRecognitionService.instance
          .validateFaceImage(pickedFile.path);

      setState(() {
        _isProcessing = false;
        _validationMessage = validationResult.message;
        _isFaceValid = validationResult.isValid;
      });

      if (!validationResult.isValid) {
        _showToast(validationResult.message, isError: true);
      } else {
        _showToast('Face validated successfully!', isError: false);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _validationMessage = 'Error: ${e.toString()}';
        _isFaceValid = false;
      });
      _showToast('Error capturing image', isError: true);
    }
  }

  Future<void> _registerPerson() async {
    if (!_formKey.currentState!.validate()) return;
    if (_capturedImage == null) {
      _showToast('Please capture an image first', isError: true);
      return;
    }
    if (!_isFaceValid) {
      _showToast('Please capture a valid face image', isError: true);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Detect face and extract features
      final faces = await FaceRecognitionService.instance
          .detectFaces(_capturedImage!.path);

      if (faces.isEmpty) {
        _showToast('No face detected', isError: true);
        setState(() => _isProcessing = false);
        return;
      }

      final face = faces.first;

      // Extract face embedding using FaceNet
      print('Extracting FaceNet embedding...');
      final embedding = await FaceNetService.instance
          .extractFaceEmbedding(_capturedImage!.path, face);

      // Convert embedding to JSON string
      final faceFeatures = PersonModel.embeddingToJson(embedding);
      print('Embedding extracted: ${embedding.length} dimensions');

      // Save image to permanent storage
      final appDir = await getApplicationDocumentsDirectory();
      final personId = const Uuid().v4();
      final fileName = '$personId.jpg';
      final savedImagePath = path.join(appDir.path, 'faces', fileName);

      // Create faces directory if it doesn't exist
      final facesDir = Directory(path.join(appDir.path, 'faces'));
      if (!await facesDir.exists()) {
        await facesDir.create(recursive: true);
      }

      // Copy image to permanent location
      await _capturedImage!.copy(savedImagePath);

      // Create person model
      final person = PersonModel(
        id: personId,
        name: _nameController.text.trim(),
        imagePath: savedImagePath,
        faceFeatures: faceFeatures,
        registeredAt: DateTime.now(),
      );

      // Save to database
      await DatabaseHelper.instance.createPerson(person);

      _showToast('Person registered successfully!', isError: false);

      // Navigate back
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showToast('Error registering person: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showToast(String message, {required bool isError}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? Colors.red : Colors.green,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Select Image Source',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF6C63FF)),
              title: Text('Camera', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                _captureImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFF6C63FF)),
              title: Text('Gallery', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                _captureImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Register New Face',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF6C63FF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Capture Section
              Container(
                height: 320,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _capturedImage == null
                    ? _buildImagePlaceholder()
                    : _buildCapturedImage(),
              ),

              const SizedBox(height: 16),

              // Validation Message
              if (_validationMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isFaceValid
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isFaceValid ? Colors.green : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isFaceValid ? Icons.check_circle : Icons.info,
                        color: _isFaceValid ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _validationMessage!,
                          style: GoogleFonts.poppins(
                            color: _isFaceValid
                                ? Colors.green[800]
                                : Colors.orange[800],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Name Input
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                    hintText: 'Enter person\'s name',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    prefixIcon:
                        const Icon(Icons.person, color: Color(0xFF6C63FF)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  style: GoogleFonts.poppins(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline,
                            color: Color(0xFF6C63FF), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Tips for Best Results',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6C63FF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildTipItem('Face the camera directly'),
                    _buildTipItem('Ensure good lighting'),
                    _buildTipItem('Keep eyes open'),
                    _buildTipItem('Only one person in frame'),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Register Button
              ElevatedButton(
                onPressed: _isProcessing ? null : _registerPerson,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Register Person',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return InkWell(
      onTap: _isProcessing ? null : _showImageSourceDialog,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt,
              size: 64,
              color: Color(0xFF6C63FF),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tap to Capture Face',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use camera or select from gallery',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapturedImage() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.file(
            _capturedImage!,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: const Color(0xFF6C63FF),
            onPressed: _isProcessing ? null : _showImageSourceDialog,
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
        ),
        if (_isProcessing)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check, size: 16, color: Color(0xFF6C63FF)),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
