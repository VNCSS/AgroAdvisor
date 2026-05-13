/// Representa os dados de uma propriedade rural no Firestore.
class PropertyModel {
  final String id;
  final String name;
  final String mainCrop;   // ex: Milho, Soja, Café
  final double latitude;
  final double longitude;
  final String ownerId;    // UID do usuário Firebase

  PropertyModel({
    required this.id,
    required this.name,
    required this.mainCrop,
    required this.latitude,
    required this.longitude,
    required this.ownerId,
  });

  /// Converte para Map para salvar no Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'mainCrop': mainCrop,
      'latitude': latitude,
      'longitude': longitude,
      'ownerId': ownerId,
    };
  }

  /// Constrói um PropertyModel a partir de um documento do Firestore
  factory PropertyModel.fromMap(String id, Map<String, dynamic> map) {
    return PropertyModel(
      id: id,
      name: map['name'] ?? '',
      mainCrop: map['mainCrop'] ?? '',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      ownerId: map['ownerId'] ?? '',
    );
  }
}
