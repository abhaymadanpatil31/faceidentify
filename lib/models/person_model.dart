import 'dart:convert';

class PersonModel {
  final String id;
  final String name;
  final String imagePath;
  final String
      faceFeatures; // JSON string: can be old features OR 128-dim embedding
  final DateTime registeredAt;

  PersonModel({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.faceFeatures,
    required this.registeredAt,
  });

  // Helper: Check if this uses new embedding format
  bool get hasEmbedding {
    try {
      final data = jsonDecode(faceFeatures);
      return data is Map &&
          data.containsKey('embedding') &&
          data['embedding'] is List;
    } catch (e) {
      return false;
    }
  }

  // Helper: Extract embedding if available
  List<double>? get embedding {
    if (!hasEmbedding) return null;
    try {
      final data = jsonDecode(faceFeatures);
      final embeddingList = data['embedding'] as List;
      return embeddingList.map((e) => (e as num).toDouble()).toList();
    } catch (e) {
      return null;
    }
  }

  // Helper: Create face features JSON from embedding
  static String embeddingToJson(List<double> embedding) {
    return jsonEncode({
      'type': 'facenet_embedding',
      'embedding': embedding,
      'version': '1.0',
    });
  }

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'faceFeatures': faceFeatures,
      'registeredAt': registeredAt.toIso8601String(),
    };
  }

  // Create from Map (database retrieval)
  factory PersonModel.fromMap(Map<String, dynamic> map) {
    return PersonModel(
      id: map['id'] as String,
      name: map['name'] as String,
      imagePath: map['imagePath'] as String,
      faceFeatures: map['faceFeatures'] as String,
      registeredAt: DateTime.parse(map['registeredAt'] as String),
    );
  }

  // Copy with method for updates
  PersonModel copyWith({
    String? id,
    String? name,
    String? imagePath,
    String? faceFeatures,
    DateTime? registeredAt,
  }) {
    return PersonModel(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      faceFeatures: faceFeatures ?? this.faceFeatures,
      registeredAt: registeredAt ?? this.registeredAt,
    );
  }
}
