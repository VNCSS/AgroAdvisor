import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// Gerencia o upload de arquivos para o Firebase Storage.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Faz o upload de uma imagem de ocorrência de praga.
  ///
  /// [imageFile]  → arquivo de imagem selecionado pelo usuário (mobile)
  /// [imageBytes] → bytes da imagem (web)
  /// [userId]     → UID do usuário (para organizar as pastas)
  ///
  /// Retorna a URL pública de download da imagem após o upload.
  Future<String> uploadOccurrenceImage({
    File? imageFile,
    Uint8List? imageBytes,
    required String userId,
  }) async {
    if (imageFile == null && imageBytes == null) {
      throw ArgumentError('Either imageFile or imageBytes must be provided');
    }

    // Caminho no Storage: occurrences/{userId}/{timestamp}.jpg
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = _storage.ref('occurrences/$userId/$fileName.jpg');

    UploadTask uploadTask;

    // Faz o upload dependendo do tipo de dados
    if (imageBytes != null) {
      // Para web: usa putData com bytes
      uploadTask = ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } else {
      // Para mobile: usa putFile com File
      uploadTask = ref.putFile(
        imageFile!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    }

    await uploadTask;

    // Retorna a URL pública acessível
    return await ref.getDownloadURL();
  }
}
