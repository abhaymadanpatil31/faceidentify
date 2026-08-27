import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceNetService {
  static final FaceNetService instance = FaceNetService._init();

  Interpreter? _interpreter;
  bool _isInitialized = false;

  FaceNetService._init();

  /// Initialize the FaceNet model
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('Loading FaceNet model...');
      _interpreter =
          await Interpreter.fromAsset('assets/models/facenet.tflite');

      // Get model input/output shapes
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;

      print('FaceNet model loaded successfully');
      print('Input shape: $inputShape');
      print('Output shape: $outputShape');

      _isInitialized = true;
    } catch (e) {
      print('Error loading FaceNet model: $e');
      rethrow;
    }
  }

  /// Extract 128-dimensional face embedding from a face region
  Future<List<double>> extractFaceEmbedding(
    String imagePath,
    Face face,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Read and decode image
      final imageFile = File(imagePath);
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Extract face region with some padding
      final boundingBox = face.boundingBox;
      const padding = 20;

      final x = max(0, boundingBox.left.toInt() - padding);
      final y = max(0, boundingBox.top.toInt() - padding);
      final width = min(
        image.width - x,
        (boundingBox.width + padding * 2).toInt(),
      );
      final height = min(
        image.height - y,
        (boundingBox.height + padding * 2).toInt(),
      );

      // Crop face region
      final faceCrop = img.copyCrop(
        image,
        x: x,
        y: y,
        width: width,
        height: height,
      );

      // Resize to model input size (160x160 for FaceNet)
      final resized = img.copyResize(faceCrop, width: 160, height: 160);

      // Normalize and prepare input as 4D tensor [1, 160, 160, 3]
      final input = _imageToInput4D(resized);

      // Prepare output buffer (128-dimensional embedding)
      final output = [List.filled(128, 0.0)];

      // Run inference
      _interpreter!.run(input, output);

      // Extract embedding as List<double>
      final embedding = List<double>.from(output[0]);

      // Normalize embedding (L2 normalization)
      final normalizedEmbedding = _normalizeEmbedding(embedding);

      print(
          'Face embedding extracted: ${normalizedEmbedding.length} dimensions');
      return normalizedEmbedding;
    } catch (e) {
      print('Error extracting face embedding: $e');
      rethrow;
    }
  }

  /// Convert image to 4D tensor [1, 160, 160, 3] for model input
  List _imageToInput4D(img.Image image) {
    final rows = <List<List<List<double>>>>[];
    final frame = <List<List<double>>>[];

    for (int y = 0; y < 160; y++) {
      final row = <List<double>>[];
      for (int x = 0; x < 160; x++) {
        final pixel = image.getPixel(x, y);
        row.add([pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0]);
      }
      frame.add(row);
    }
    rows.add(frame);
    return rows;
  }

  /// L2 normalization of embedding vector
  List<double> _normalizeEmbedding(List<double> embedding) {
    double sumSquares = 0.0;
    for (final value in embedding) {
      sumSquares += value * value;
    }

    final magnitude = sqrt(sumSquares);

    if (magnitude == 0) return embedding;

    return embedding.map((value) => value / magnitude).toList();
  }

  /// Calculate cosine similarity between two embeddings (0-1, higher = more similar)
  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      throw ArgumentError('Embeddings must have the same length');
    }

    double dotProduct = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
    }

    // Since embeddings are L2 normalized, cosine similarity = dot product
    // Convert from [-1, 1] to [0, 100] percentage
    final similarity = ((dotProduct + 1) / 2) * 100;

    return similarity.clamp(0, 100);
  }

  /// Calculate Euclidean distance between embeddings (lower = more similar)
  double calculateDistance(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      throw ArgumentError('Embeddings must have the same length');
    }

    double sumSquares = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      final diff = embedding1[i] - embedding2[i];
      sumSquares += diff * diff;
    }

    return sqrt(sumSquares);
  }

  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }
}

