import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa um registro de ocorrência de praga (Radar Colaborativo).
class OccurrenceModel {
  final String id;
  final String imageUrl;    // URL pública do Firebase Storage
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String reportedBy;  // UID do usuário que registrou

  OccurrenceModel({
    required this.id,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.reportedBy,
  });

  /// Converte para Map para salvar no Firestore
  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp), // tipo nativo do Firestore
      'reportedBy': reportedBy,
    };
  }

  /// Constrói um OccurrenceModel a partir de um documento do Firestore
  factory OccurrenceModel.fromMap(String id, Map<String, dynamic> map) {
    return OccurrenceModel(
      id: id,
      imageUrl: map['imageUrl'] ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      reportedBy: map['reportedBy'] ?? '',
    );
  }
}
