import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  final bool read;
  final String? occurrenceId;
  final double? latitude;
  final double? longitude;

  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    required this.read,
    this.occurrenceId,
    this.latitude,
    this.longitude,
  });

  factory AppNotificationModel.fromMap(Map<String, dynamic> map, String id) {
    final raw = map['receivedAt'];
    final receivedAt = raw is Timestamp ? raw.toDate() : DateTime.now();
    return AppNotificationModel(
      id: id,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      receivedAt: receivedAt,
      read: map['read'] == true,
      occurrenceId: map['occurrenceId'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }
}
