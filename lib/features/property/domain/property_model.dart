/// Representa uma propriedade rural no Firestore.
class PropertyModel {
  final String id;
  final String name;
  final String mainCrop;
  final double latitude;
  final double longitude;
  final String ownerId;

  const PropertyModel({
    required this.id,
    required this.name,
    required this.mainCrop,
    required this.latitude,
    required this.longitude,
    required this.ownerId,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'mainCrop': mainCrop,
        'latitude': latitude,
        'longitude': longitude,
        'ownerId': ownerId,
      };

  factory PropertyModel.fromMap(String id, Map<String, dynamic> map) =>
      PropertyModel(
        id: id,
        name: map['name'] ?? '',
        mainCrop: map['mainCrop'] ?? '',
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        ownerId: map['ownerId'] ?? '',
      );
}
