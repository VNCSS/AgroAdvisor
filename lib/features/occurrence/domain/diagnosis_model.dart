import 'package:cloud_firestore/cloud_firestore.dart';

class DiagnosisModel {
  final String pestName;
  final String riskLevel; // 'alto' | 'médio' | 'baixo'
  final String description;
  final String recommendation;
  final double confidenceScore; // 0.0 – 1.0
  final List<String> detectedIssues;
  final DateTime analyzedAt;

  const DiagnosisModel({
    required this.pestName,
    required this.riskLevel,
    required this.description,
    required this.recommendation,
    required this.confidenceScore,
    required this.detectedIssues,
    required this.analyzedAt,
  });

  Map<String, dynamic> toMap() => {
        'pestName': pestName,
        'riskLevel': riskLevel,
        'description': description,
        'recommendation': recommendation,
        'confidenceScore': confidenceScore,
        'detectedIssues': detectedIssues,
        'analyzedAt': Timestamp.fromDate(analyzedAt),
      };

  factory DiagnosisModel.fromMap(Map<String, dynamic> map) {
    final raw = map['analyzedAt'];
    final analyzedAt = raw is Timestamp ? raw.toDate() : DateTime.now();
    return DiagnosisModel(
      pestName: map['pestName'] ?? 'Não identificado',
      riskLevel: map['riskLevel'] ?? 'desconhecido',
      description: map['description'] ?? '',
      recommendation: map['recommendation'] ?? '',
      confidenceScore: (map['confidenceScore'] ?? 0.0).toDouble(),
      detectedIssues: List<String>.from(map['detectedIssues'] ?? []),
      analyzedAt: analyzedAt,
    );
  }
}
