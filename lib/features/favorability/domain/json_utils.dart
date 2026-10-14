// Leitura tolerante de JSON para a base científica.
//
// Campos ausentes viram null (nunca um valor padrão inventado). Campos
// presentes com tipo errado lançam FormatException, para que um erro de
// cadastro não passe despercebido como "parâmetro ausente".

String? readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Campo "$key" deveria ser texto', value);
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? readDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! num) {
    throw FormatException('Campo "$key" deveria ser numérico', value);
  }
  return value.toDouble();
}

int? readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int) {
    throw FormatException('Campo "$key" deveria ser inteiro', value);
  }
  return value;
}

bool? readBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! bool) {
    throw FormatException('Campo "$key" deveria ser booleano', value);
  }
  return value;
}

List<String> readStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List || value.any((e) => e is! String)) {
    throw FormatException('Campo "$key" deveria ser lista de textos', value);
  }
  return List.unmodifiable(
    value.cast<String>().map((e) => e.trim()).where((e) => e.isNotEmpty),
  );
}

Map<String, dynamic>? readObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! Map<String, dynamic>) {
    throw FormatException('Campo "$key" deveria ser objeto', value);
  }
  return value;
}

List<Map<String, dynamic>> readObjectList(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List || value.any((e) => e is! Map<String, dynamic>)) {
    throw FormatException('Campo "$key" deveria ser lista de objetos', value);
  }
  return value.cast<Map<String, dynamic>>();
}

/// Datas são armazenadas como "AAAA-MM-DD" (ISO 8601).
DateTime? readDate(Map<String, dynamic> json, String key) {
  final raw = readString(json, key);
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw FormatException('Campo "$key" deveria ser data ISO 8601', raw);
  }
  return parsed;
}

String? formatDate(DateTime? date) {
  if (date == null) return null;
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Remove entradas nulas para manter o JSON serializado enxuto.
Map<String, dynamic> compactJson(Map<String, dynamic> map) =>
    Map.fromEntries(map.entries.where((e) => e.value != null));
