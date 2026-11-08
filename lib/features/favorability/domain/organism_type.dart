/// Classificação biológica do organismo descrito por uma regra científica.
///
/// O tipo é definido por quem cadastra a regra (curadoria), NÃO pela IA.
/// A IA pode classificar errado — por isso a busca de regras usa apenas o
/// nome do organismo e nunca filtra pelo tipo que a IA informou.
enum OrganismType {
  /// Fungo / doença fúngica (ex.: ferrugens, oídios, antracnoses).
  fungus('fungus'),

  /// Inseto (ex.: lagartas, percevejos, moscas-brancas).
  insect('insect'),

  /// Bactéria / doença bacteriana.
  bacterium('bacterium'),

  /// Outros organismos (ácaros, nematoides, vírus, oomicetos, plantas
  /// daninhas…). Detalhe no campo de observação da regra, se necessário.
  other('other'),

  /// Doença cujo agente causal não está classificado.
  unclassifiedDisease('unclassified_disease'),

  /// Tipo não informado ou não reconhecido.
  unknown('unknown');

  const OrganismType(this.key);

  /// Valor persistido no JSON.
  final String key;

  /// Converte texto livre (JSON ou saída da IA) em [OrganismType].
  ///
  /// Aceita variações em português e inglês. Qualquer valor não reconhecido
  /// vira [unknown] em vez de lançar exceção.
  static OrganismType parse(String? raw) {
    if (raw == null) return unknown;
    final value = raw.trim().toLowerCase();
    for (final type in values) {
      if (type.key == value) return type;
    }
    return _aliases[value] ?? unknown;
  }

  static const Map<String, OrganismType> _aliases = {
    'fungo': fungus,
    'fungi': fungus,
    'doença fúngica': fungus,
    'doenca fungica': fungus,
    'inseto': insect,
    'praga': insect,
    'bacteria': bacterium,
    'bactéria': bacterium,
    'doença bacteriana': bacterium,
    'doenca bacteriana': bacterium,
    'outro': other,
    'outros': other,
    'doença não classificada': unclassifiedDisease,
    'doenca nao classificada': unclassifiedDisease,
    'unclassified': unclassifiedDisease,
  };
}
