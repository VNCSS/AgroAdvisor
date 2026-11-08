import 'criteria.dart';
import 'json_utils.dart';
import 'organism_name.dart';
import 'organism_type.dart';
import 'scientific_source.dart';

/// Grau de confiança da curadoria na evidência que sustenta a regra.
enum EvidenceConfidence {
  low('low'),
  moderate('moderate'),
  high('high');

  const EvidenceConfidence(this.key);
  final String key;

  static EvidenceConfidence? parse(String? raw) {
    if (raw == null) return null;
    for (final c in values) {
      if (c.key == raw) return c;
    }
    throw FormatException('Confiança desconhecida', raw);
  }
}

/// Conhecimento científico sobre as condições que favorecem um organismo.
///
/// É genérica: qualquer organismo (fungo, inseto, bactéria…) é descrito
/// pelos mesmos campos, e o futuro motor de risco avalia todos da mesma
/// forma. Adicionar um organismo = adicionar dados, não código.
///
/// Nenhum critério é obrigatório. Critério ausente (null) significa que a
/// fonte não fornece aquele parâmetro — o motor deve ignorá-lo, não
/// tratá-lo como zero.
///
/// O motor só deve usar a regra se [isUsable] for true. Caso contrário,
/// [unusableReasons] explica o motivo (evidência insuficiente, sem fonte…).
class ScientificPestRule {
  /// Identificador estável da regra (ex.: "phakopsora-pachyrhizi").
  final String id;

  /// Nome popular de exibição (ex.: "Ferrugem asiática").
  final String organismName;

  /// Nome científico, quando aplicável.
  final String? scientificName;

  /// Outros nomes pelos quais a IA pode identificar o organismo.
  final List<String> aliases;

  final OrganismType organismType;

  /// Culturas afetadas, como texto livre (ex.: "Soja"). Vazio = a regra não
  /// restringe culturas (ou a fonte não especifica).
  final List<String> affectedCrops;

  final TemperatureCriteria? temperature;
  final HumidityCriteria? humidity;
  final PrecipitationCriteria? precipitation;
  final LeafWetnessCriteria? leafWetness;
  final DewPointCriteria? dewPoint;
  final DegreeDayCriteria? degreeDays;
  final WindCriteria? wind;
  final PhenologyCriteria? phenology;
  final List<AdditionalCriterion> additionalCriteria;

  final List<ScientificSource> sources;

  /// Data da última revisão da regra pela curadoria.
  final DateTime? lastReviewedAt;

  /// false quando não há evidência científica suficiente. O organismo fica
  /// cadastrado (para ser reconhecido), mas o motor não deve calcular risco.
  final bool available;

  /// Explica por que a regra está indisponível, quando [available] = false.
  final String? unavailabilityReason;

  final EvidenceConfidence? confidence;

  /// Observações gerais da curadoria.
  final String? note;

  const ScientificPestRule({
    required this.id,
    required this.organismName,
    this.scientificName,
    this.aliases = const [],
    this.organismType = OrganismType.unknown,
    this.affectedCrops = const [],
    this.temperature,
    this.humidity,
    this.precipitation,
    this.leafWetness,
    this.dewPoint,
    this.degreeDays,
    this.wind,
    this.phenology,
    this.additionalCriteria = const [],
    this.sources = const [],
    this.lastReviewedAt,
    this.available = false,
    this.unavailabilityReason,
    this.confidence,
    this.note,
  });

  String get normalizedName => normalizeOrganismName(organismName);

  /// Todos os nomes normalizados que identificam este organismo
  /// (nome popular, nome científico e sinônimos).
  Set<String> get normalizedNames => {
        normalizedName,
        if (scientificName != null) normalizeOrganismName(scientificName!),
        ...aliases.map(normalizeOrganismName),
      }..remove('');

  /// Critérios ambientais preenchidos, na ordem do modelo.
  List<Criterion> get criteria => [
        ?temperature,
        ?humidity,
        ?precipitation,
        ?leafWetness,
        ?dewPoint,
        ?degreeDays,
        ?wind,
        ?phenology,
        ...additionalCriteria,
      ];

  /// Critérios com ao menos um parâmetro objetivo, avaliáveis pelo motor.
  List<Criterion> get evaluableCriteria =>
      criteria.where((c) => c.hasParameters).toList();

  /// true se a regra se aplica à cultura; null se a regra não especifica
  /// culturas (o motor decide como tratar a incerteza).
  bool? appliesToCrop(String crop) {
    if (affectedCrops.isEmpty) return null;
    final target = normalizeOrganismName(crop);
    return affectedCrops.any((c) => normalizeOrganismName(c) == target);
  }

  /// Problemas de consistência dos dados (independe de [available]).
  List<String> validate() {
    final issues = <String>[];
    if (id.trim().isEmpty) issues.add('Regra sem id');
    if (normalizedName.isEmpty) issues.add('Regra sem nome de organismo');

    final sourceIds = <String>{};
    for (final s in sources) {
      if (!sourceIds.add(s.id)) issues.add('Fonte duplicada: "${s.id}"');
    }
    for (final c in criteria) {
      issues.addAll(c.validate());
      for (final ref in c.sourceIds) {
        if (!sourceIds.contains(ref)) {
          issues.add('Critério cita fonte inexistente: "$ref"');
        }
      }
    }
    return issues;
  }

  /// Motivos que impedem o motor de usar a regra. Vazio = utilizável.
  List<String> get unusableReasons {
    final reasons = <String>[];
    if (!available) {
      reasons.add(unavailabilityReason ?? 'Evidência científica insuficiente');
      return reasons;
    }
    if (!sources.any((s) => s.isIdentifiable)) {
      reasons.add('Sem fonte científica identificável (título e URL)');
    }
    if (evaluableCriteria.isEmpty) {
      reasons.add('Nenhum parâmetro ambiental avaliável');
    }
    reasons.addAll(validate());
    return reasons;
  }

  bool get isUsable => unusableReasons.isEmpty;

  factory ScientificPestRule.fromJson(Map<String, dynamic> json) {
    final id = readString(json, 'id');
    final organismName = readString(json, 'organismName');
    if (id == null || organismName == null) {
      throw const FormatException('Regra sem "id" ou "organismName"');
    }
    T? obj<T>(String key, T Function(Map<String, dynamic>) parse) {
      final map = readObject(json, key);
      return map == null ? null : parse(map);
    }

    return ScientificPestRule(
      id: id,
      organismName: organismName,
      scientificName: readString(json, 'scientificName'),
      aliases: readStringList(json, 'aliases'),
      organismType: OrganismType.parse(readString(json, 'organismType')),
      affectedCrops: readStringList(json, 'affectedCrops'),
      temperature: obj('temperature', TemperatureCriteria.fromJson),
      humidity: obj('humidity', HumidityCriteria.fromJson),
      precipitation: obj('precipitation', PrecipitationCriteria.fromJson),
      leafWetness: obj('leafWetness', LeafWetnessCriteria.fromJson),
      dewPoint: obj('dewPoint', DewPointCriteria.fromJson),
      degreeDays: obj('degreeDays', DegreeDayCriteria.fromJson),
      wind: obj('wind', WindCriteria.fromJson),
      phenology: obj('phenology', PhenologyCriteria.fromJson),
      additionalCriteria: List.unmodifiable(
        readObjectList(json, 'additionalCriteria')
            .map(AdditionalCriterion.fromJson),
      ),
      sources: List.unmodifiable(
        readObjectList(json, 'sources').map(ScientificSource.fromJson),
      ),
      lastReviewedAt: readDate(json, 'lastReviewedAt'),
      // Ausente = indisponível: a regra precisa ser liberada explicitamente.
      available: readBool(json, 'available') ?? false,
      unavailabilityReason: readString(json, 'unavailabilityReason'),
      confidence: EvidenceConfidence.parse(readString(json, 'confidence')),
      note: readString(json, 'note'),
    );
  }

  Map<String, dynamic> toJson() => compactJson({
        'id': id,
        'organismName': organismName,
        'scientificName': scientificName,
        'aliases': aliases.isEmpty ? null : aliases,
        'organismType': organismType.key,
        'affectedCrops': affectedCrops.isEmpty ? null : affectedCrops,
        'temperature': temperature?.toJson(),
        'humidity': humidity?.toJson(),
        'precipitation': precipitation?.toJson(),
        'leafWetness': leafWetness?.toJson(),
        'dewPoint': dewPoint?.toJson(),
        'degreeDays': degreeDays?.toJson(),
        'wind': wind?.toJson(),
        'phenology': phenology?.toJson(),
        'additionalCriteria': additionalCriteria.isEmpty
            ? null
            : additionalCriteria.map((c) => c.toJson()).toList(),
        'sources':
            sources.isEmpty ? null : sources.map((s) => s.toJson()).toList(),
        'lastReviewedAt': formatDate(lastReviewedAt),
        'available': available,
        'unavailabilityReason': unavailabilityReason,
        'confidence': confidence?.key,
        'note': note,
      });
}
