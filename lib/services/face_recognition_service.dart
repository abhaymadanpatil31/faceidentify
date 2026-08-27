import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show Rect;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import '../models/person_model.dart';

class FaceRecognitionService {
  static final FaceRecognitionService instance = FaceRecognitionService._init();

  late final FaceDetector _faceDetector;

  FaceRecognitionService._init() {
    final options = FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: true,
      enableClassification: true,
      enableTracking: false,
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);
  }

  // Detect faces in an image
  Future<List<Face>> detectFaces(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final faces = await _faceDetector.processImage(inputImage);
    return faces;
  }

  // Extract face features for storage and comparison
  Future<String> extractFaceFeatures(Face face, String imagePath) async {
    final features = <String, dynamic>{};

    // Store bounding box
    features['boundingBox'] = {
      'left': face.boundingBox.left,
      'top': face.boundingBox.top,
      'right': face.boundingBox.right,
      'bottom': face.boundingBox.bottom,
    };

    // Store landmarks if available
    final landmarks = <String, Map<String, double>>{};

    if (face.landmarks[FaceLandmarkType.leftEye] != null) {
      final leftEye = face.landmarks[FaceLandmarkType.leftEye]!.position;
      landmarks['leftEye'] = {
        'x': leftEye.x.toDouble(),
        'y': leftEye.y.toDouble(),
      };
    }

    if (face.landmarks[FaceLandmarkType.rightEye] != null) {
      final rightEye = face.landmarks[FaceLandmarkType.rightEye]!.position;
      landmarks['rightEye'] = {
        'x': rightEye.x.toDouble(),
        'y': rightEye.y.toDouble(),
      };
    }

    if (face.landmarks[FaceLandmarkType.noseBase] != null) {
      final noseBase = face.landmarks[FaceLandmarkType.noseBase]!.position;
      landmarks['noseBase'] = {
        'x': noseBase.x.toDouble(),
        'y': noseBase.y.toDouble(),
      };
    }

    if (face.landmarks[FaceLandmarkType.leftMouth] != null) {
      final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]!.position;
      landmarks['leftMouth'] = {
        'x': leftMouth.x.toDouble(),
        'y': leftMouth.y.toDouble(),
      };
    }

    if (face.landmarks[FaceLandmarkType.rightMouth] != null) {
      final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]!.position;
      landmarks['rightMouth'] = {
        'x': rightMouth.x.toDouble(),
        'y': rightMouth.y.toDouble(),
      };
    }

    features['landmarks'] = landmarks;

    // Store head rotation angles
    features['headEulerAngleY'] = face.headEulerAngleY ?? 0;
    features['headEulerAngleZ'] = face.headEulerAngleZ ?? 0;

    // Store classification probabilities
    features['smilingProbability'] = face.smilingProbability ?? 0;
    features['leftEyeOpenProbability'] = face.leftEyeOpenProbability ?? 0;
    features['rightEyeOpenProbability'] = face.rightEyeOpenProbability ?? 0;

    // Calculate additional metrics
    if (landmarks.containsKey('leftEye') && landmarks.containsKey('rightEye')) {
      final eyeDistance = _calculateDistance(
        landmarks['leftEye']!,
        landmarks['rightEye']!,
      );
      features['eyeDistance'] = eyeDistance;
    }

    // Extract pixel data from face region for more accurate matching
    final pixelData = await _extractFacePixelData(imagePath, face.boundingBox);
    features['pixelSignature'] = pixelData;

    return jsonEncode(features);
  }

  // Extract simplified pixel data from face region
  Future<List<int>> _extractFacePixelData(
    String imagePath,
    Rect boundingBox,
  ) async {
    try {
      final imageFile = File(imagePath);
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return [];

      // Extract face region
      final x = boundingBox.left.toInt().clamp(0, image.width - 1);
      final y = boundingBox.top.toInt().clamp(0, image.height - 1);
      final width = (boundingBox.right - boundingBox.left).toInt().clamp(
            1,
            image.width - x,
          );
      final height = (boundingBox.bottom - boundingBox.top).toInt().clamp(
            1,
            image.height - y,
          );

      final faceCrop = img.copyCrop(
        image,
        x: x,
        y: y,
        width: width,
        height: height,
      );

      // Resize to standard size for consistent comparison
      final resized = img.copyResize(faceCrop, width: 64, height: 64);

      // Convert to grayscale and extract pixel values
      final grayscale = img.grayscale(resized);
      final pixels = <int>[];

      // Sample every 4th pixel to reduce data size
      for (int py = 0; py < grayscale.height; py += 2) {
        for (int px = 0; px < grayscale.width; px += 2) {
          final pixel = grayscale.getPixel(px, py);
          pixels.add(pixel.r.round());
        }
      }

      return pixels;
    } catch (e) {
      print('Error extracting pixel data: $e');
      return [];
    }
  }

  // Calculate Euclidean distance between two points
  double _calculateDistance(
    Map<String, double> point1,
    Map<String, double> point2,
  ) {
    final dx = point1['x']! - point2['x']!;
    final dy = point1['y']! - point2['y']!;
    return sqrt(dx * dx + dy * dy);
  }

  // Compare two faces and return similarity score (0-100)
  double compareFaces(String features1Json, String features2Json) {
    try {
      final features1 = jsonDecode(features1Json) as Map<String, dynamic>;
      final features2 = jsonDecode(features2Json) as Map<String, dynamic>;

      double totalScore = 0;
      double scoreCount = 0;

      // Compare eye distance (important but normalized for scale)
      if (features1['eyeDistance'] != null &&
          features2['eyeDistance'] != null) {
        final dist1 = features1['eyeDistance'] as double;
        final dist2 = features2['eyeDistance'] as double;
        final distDiff = (dist1 - dist2).abs();
        // More lenient - normalize by average
        final avgDist = (dist1 + dist2) / 2;
        final normalizedDiff = avgDist > 0 ? (distDiff / avgDist) * 100 : 100;
        final distScore = max(0, 100 - normalizedDiff);
        print('Eye distance: $dist1 vs $dist2, score: $distScore');
        totalScore += distScore * 1.0; // Reduced weight due to scale issues
        scoreCount += 1.0;
      }

      // Compare landmarks
      final landmarks1 = features1['landmarks'] as Map<String, dynamic>?;
      final landmarks2 = features2['landmarks'] as Map<String, dynamic>?;

      if (landmarks1 != null && landmarks2 != null) {
        final landmarkTypes = [
          'leftEye',
          'rightEye',
          'noseBase',
          'leftMouth',
          'rightMouth',
        ];

        for (final landmarkType in landmarkTypes) {
          if (landmarks1[landmarkType] != null &&
              landmarks2[landmarkType] != null) {
            final point1 = landmarks1[landmarkType] as Map<String, dynamic>;
            final point2 = landmarks2[landmarkType] as Map<String, dynamic>;

            final distance = _calculateDistance(
              {'x': point1['x'] as double, 'y': point1['y'] as double},
              {'x': point2['x'] as double, 'y': point2['y'] as double},
            );

            final landmarkScore = max(0, 100 - distance);
            totalScore += landmarkScore * 1.5; // Medium weight
            scoreCount += 1.5;
          }
        }
      }

      // Compare pixel signatures (most important - scale invariant)
      if (features1['pixelSignature'] != null &&
          features2['pixelSignature'] != null) {
        final pixels1 = List<int>.from(features1['pixelSignature'] as List);
        final pixels2 = List<int>.from(features2['pixelSignature'] as List);

        if (pixels1.length == pixels2.length && pixels1.isNotEmpty) {
          double pixelDiff = 0;
          for (int i = 0; i < pixels1.length; i++) {
            pixelDiff += (pixels1[i] - pixels2[i]).abs();
          }
          final avgDiff = pixelDiff / pixels1.length;
          final pixelScore = max(0, 100 - avgDiff);
          print('Pixel comparison score: $pixelScore');
          totalScore += pixelScore * 5.0; // Increased weight - most reliable
          scoreCount += 5.0;
        }
      }

      // Compare head angles
      final angle1Y = features1['headEulerAngleY'] as double? ?? 0;
      final angle2Y = features2['headEulerAngleY'] as double? ?? 0;
      final angleDiffY = (angle1Y - angle2Y).abs();
      final angleScoreY = max(0, 100 - angleDiffY);
      totalScore += angleScoreY * 0.5;
      scoreCount += 0.5;

      return scoreCount > 0 ? (totalScore / scoreCount).clamp(0, 100) : 0;
    } catch (e) {
      print('Error comparing faces: $e');
      return 0;
    }
  }

  // Find best match from a list of persons
  Future<MatchResult?> findBestMatch(
    String targetFaceFeatures,
    List<PersonModel> persons, {
    double threshold = 35.0, // Lowered temporarily for testing
  }) async {
    if (persons.isEmpty) return null;

    double bestScore = 0;
    PersonModel? bestMatch;

    print('=== Face Matching Debug ===');
    print('Comparing against ${persons.length} registered persons...');

    for (final person in persons) {
      final score = compareFaces(targetFaceFeatures, person.faceFeatures);
      print('Match with ${person.name}: ${score.toStringAsFixed(2)}%');
      if (score > bestScore) {
        bestScore = score;
        bestMatch = person;
      }
    }

    print(
        'Best match: ${bestMatch?.name ?? "None"} with ${bestScore.toStringAsFixed(2)}%');
    print('Threshold: $threshold%');
    print('========================');

    if (bestMatch != null && bestScore >= threshold) {
      return MatchResult(person: bestMatch, confidence: bestScore);
    }

    return null;
  }

  // Validate if image contains exactly one clear face
  Future<ValidationResult> validateFaceImage(String imagePath) async {
    try {
      final faces = await detectFaces(imagePath);

      if (faces.isEmpty) {
        return ValidationResult(
          isValid: false,
          message:
              'No face detected. Please ensure your face is clearly visible.',
        );
      }

      if (faces.length > 1) {
        return ValidationResult(
          isValid: false,
          message:
              'Multiple faces detected. Please ensure only one person is in the frame.',
        );
      }

      final face = faces.first;

      // Check if eyes are open
      final leftEyeOpen = face.leftEyeOpenProbability ?? 0;
      final rightEyeOpen = face.rightEyeOpenProbability ?? 0;

      if (leftEyeOpen < 0.5 || rightEyeOpen < 0.5) {
        return ValidationResult(
          isValid: false,
          message: 'Please keep your eyes open for better recognition.',
        );
      }

      // Check head rotation
      final yaw = (face.headEulerAngleY ?? 0).abs();
      if (yaw > 15) {
        return ValidationResult(
          isValid: false,
          message: 'Please face the camera directly.',
        );
      }

      return ValidationResult(
        isValid: true,
        message: 'Face detected successfully!',
        face: face,
      );
    } catch (e) {
      return ValidationResult(
        isValid: false,
        message: 'Error processing image: ${e.toString()}',
      );
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}

// Result classes
class MatchResult {
  final PersonModel person;
  final double confidence;

  MatchResult({required this.person, required this.confidence});
}

class ValidationResult {
  final bool isValid;
  final String message;
  final Face? face;

  ValidationResult({required this.isValid, required this.message, this.face});
}
