import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/property_model.dart';

/// Repositório de propriedades rurais.
///
/// Encapsula todas as operações Firestore da feature property,
/// impedindo que as telas acessem o Firestore diretamente.
class PropertyRepository {
  final FirebaseFirestore _db;

  PropertyRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(AppConstants.colProperties);

  Future<void> save(PropertyModel property) async {
    if (property.id.isEmpty) {
      await _col.add(property.toMap());
    } else {
      await _col.doc(property.id).set(property.toMap());
    }
  }

  Future<List<PropertyModel>> getByOwner(String ownerId) async {
    final snap = await _col.where('ownerId', isEqualTo: ownerId).get();
    return snap.docs
        .map((d) => PropertyModel.fromMap(d.id, d.data()))
        .toList();
  }

  Future<void> delete(String propertyId) async {
    await _col.doc(propertyId).delete();
  }
}
