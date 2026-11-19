import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  /// Valor de [type] dos alertas preventivos de favorabilidade. Documentos
  /// antigos (alertas de proximidade) não têm o campo → [type] null.
  static const String typePreventive = 'preventive';

  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  final bool read;
  final String? occurrenceId;
  final double? latitude;
  final double? longitude;
  final String? type;
  final String? region, source, level, deliveryStatus, propertyId;
  final int? favorabilityIndex;
  final bool simulated;

  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    required this.read,
    this.occurrenceId,
    this.latitude,
    this.longitude,
    this.type,
    this.region,
    this.source,
    this.level,
    this.deliveryStatus,
    this.propertyId,
    this.favorabilityIndex,
    this.simulated = false,
  });

  bool get isPreventive => type == typePreventive;
  String get levelLabel => switch (level) {
    'low' => 'Baixo',
    'moderate' => 'Moderado',
    'high' => 'Alto',
    'veryHigh' => 'Muito alto',
    _ => 'não informado',
  };

  factory AppNotificationModel.fromMap(Map<String, dynamic> map, String id) {
    final raw = map['receivedAt'];
    final receivedAt = raw is Timestamp
        ? raw.toDate()
        : DateTime.tryParse(raw?.toString() ?? '') ?? DateTime.now();
    return AppNotificationModel(
      id: id,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      receivedAt: receivedAt,
      read: map['read'] == true,
      occurrenceId: map['occurrenceId'] as String?,
      latitude: num.tryParse('${map['latitude']}')?.toDouble(),
      longitude: num.tryParse('${map['longitude']}')?.toDouble(),
      type: map['type'] as String?,
      region: map['region'] as String?,
      source: map['source'] as String?,
      level: map['level'] as String?,
      deliveryStatus: map['deliveryStatus'] as String?,
      propertyId: map['propertyId'] as String?,
      favorabilityIndex: num.tryParse('${map['favorabilityIndex']}')?.toInt(),
      simulated: map['simulated'] == true,
    );
  }
}
