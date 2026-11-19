import 'json_utils.dart';

/// Referência científica que fundamenta uma regra ou parâmetro.
///
/// Toda regra utilizável precisa de pelo menos uma fonte com [title] e
/// [url]. Fontes devem ser documentos reais e verificáveis (artigos,
/// boletins técnicos da Embrapa, publicações de universidades etc.).
class ScientificSource {
  /// Identificador local da fonte dentro da regra (ex.: "embrapa-2015").
  /// Permite que cada critério indique de qual fonte veio ([sourceIds]).
  final String id;

  final String title;

  /// Instituição responsável (ex.: "Embrapa Soja").
  final String? institution;

  final List<String> authors;
  final String? url;

  /// Ano de publicação, quando conhecido.
  final int? year;

  /// Observação livre (ex.: página/tabela de onde o parâmetro foi extraído).
  final String? note;

  /// Data em que a fonte foi consultada/revisada pela curadoria.
  final DateTime? reviewedAt;

  const ScientificSource({
    required this.id,
    required this.title,
    this.institution,
    this.authors = const [],
    this.url,
    this.year,
    this.note,
    this.reviewedAt,
  });

  /// Uma fonte é identificável quando tem título e URL preenchidos.
  bool get isIdentifiable =>
      title.trim().isNotEmpty && (url?.trim().isNotEmpty ?? false);

  factory ScientificSource.fromJson(Map<String, dynamic> json) {
    final id = readString(json, 'id');
    final title = readString(json, 'title');
    if (id == null || title == null) {
      throw const FormatException('Fonte científica sem "id" ou "title"');
    }
    return ScientificSource(
      id: id,
      title: title,
      institution: readString(json, 'institution'),
      authors: readStringList(json, 'authors'),
      url: readString(json, 'url'),
      year: readInt(json, 'year'),
      note: readString(json, 'note'),
      reviewedAt: readDate(json, 'reviewedAt'),
    );
  }

  Map<String, dynamic> toJson() => compactJson({
        'id': id,
        'title': title,
        'institution': institution,
        'authors': authors.isEmpty ? null : authors,
        'url': url,
        'year': year,
        'note': note,
        'reviewedAt': formatDate(reviewedAt),
      });
}
