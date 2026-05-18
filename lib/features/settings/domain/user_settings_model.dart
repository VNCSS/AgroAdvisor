import '../../../core/constants/app_constants.dart';

class UserSettingsModel {
  final String userId;
  final String? fcmToken;
  final double alertRadiusKm;
  final bool notificationsEnabled;

  const UserSettingsModel({
    required this.userId,
    this.fcmToken,
    this.alertRadiusKm = AppConstants.alertRadiusDefault,
    this.notificationsEnabled = true,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'fcmToken': fcmToken,
        'alertRadiusKm': alertRadiusKm,
        'notificationsEnabled': notificationsEnabled,
      };

  factory UserSettingsModel.fromMap(Map<String, dynamic> map) =>
      UserSettingsModel(
        userId: map['userId'] ?? '',
        fcmToken: map['fcmToken'] as String?,
        alertRadiusKm: (map['alertRadiusKm'] ?? AppConstants.alertRadiusDefault).toDouble(),
        notificationsEnabled: map['notificationsEnabled'] ?? true,
      );

  UserSettingsModel copyWith({
    String? fcmToken,
    double? alertRadiusKm,
    bool? notificationsEnabled,
  }) =>
      UserSettingsModel(
        userId: userId,
        fcmToken: fcmToken ?? this.fcmToken,
        alertRadiusKm: alertRadiusKm ?? this.alertRadiusKm,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      );
}
