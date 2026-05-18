import 'package:cloud_firestore/cloud_firestore.dart';

import 'diagnosis_model.dart';

class OccurrenceModel {
  final String id;
  final String imageBase64;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String reportedBy;
  final DiagnosisModel? diagnosis;

  const OccurrenceModel({
    required this.id,
    required this.imageBase64,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.reportedBy,
    this.diagnosis,
  });

  Map<String, dynamic> toMap() => {
        'imageBase64': imageBase64,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': Timestamp.fromDate(timestamp),
        'reportedBy': reportedBy,
        if (diagnosis != null) 'diagnosis': diagnosis!.toMap(),
      };

  factory OccurrenceModel.fromMap(Map<String, dynamic> map, String id) {
    final raw = map['timestamp'];
    final DateTime timestamp;
    if (raw is Timestamp) {
      timestamp = raw.toDate();
    } else if (raw is DateTime) {
      timestamp = raw;
    } else {
      timestamp = DateTime.tryParse(raw?.toString() ?? '') ?? DateTime.now();
    }

    DiagnosisModel? diagnosis;
    final rawDiag = map['diagnosis'];
    if (rawDiag is Map) {
      try {
        diagnosis = DiagnosisModel.fromMap(Map<String, dynamic>.from(rawDiag));
      } catch (_) {
        // diagnóstico corrompido — exibe ocorrência sem ele
      }
    }

    return OccurrenceModel(
      id: id,
      imageBase64: map['imageBase64'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      timestamp: timestamp,
      reportedBy: map['reportedBy'] ?? '',
      diagnosis: diagnosis,
    );
  }
}
