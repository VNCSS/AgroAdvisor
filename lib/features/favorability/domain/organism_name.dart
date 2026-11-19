/// Normaliza nomes de organismos para comparação.
///
/// A IA devolve nomes em texto livre ("Ferrugem Asiática", "ferrugem-asiatica",
/// "Phakopsora pachyrhizi"). A normalização remove acentos, caixa e
/// pontuação para que a busca de regras não dependa da grafia exata.
///
/// Exemplo: "Ferrugem  Asiática (soja)" → "ferrugem asiatica soja".
String normalizeOrganismName(String raw) {
  final buffer = StringBuffer();
  for (final rune in raw.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accentMap[char] ?? char);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

const Map<String, String> _accentMap = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};
