// ⚠️ DADOS DE TESTE — NÃO SÃO CONHECIMENTO CIENTÍFICO.
//
// Organismos, valores e fontes abaixo são FICTÍCIOS, criados apenas para
// exercitar a estrutura da base científica. Os organismos têm nomes
// artificiais e as URLs usam o domínio reservado example.org justamente
// para que nunca sejam confundidos com dados reais. Não copie estes
// valores para assets/scientific_rules/.

import 'dart:convert';

Map<String, dynamic> decodeFixture(Map<String, dynamic> literal) =>
    jsonDecode(jsonEncode(literal)) as Map<String, dynamic>;

/// Regra fictícia com todos os critérios preenchidos.
const Map<String, dynamic> completeRuleJson = {
  'id': 'test-fungus-a',
  'organismName': 'Fungo de Teste Á',
  'scientificName': 'Testus fictitius',
  'aliases': ['Mancha de teste', 'TESTE-A'],
  'organismType': 'fungus',
  'affectedCrops': ['Soja', 'Milho', 'Feijão'],
  'temperature': {
    'min': 10.0,
    'max': 30.0,
    'optimal': 20.0,
    'optimalMin': 18.0,
    'optimalMax': 24.0,
    'sourceIds': ['test-src-1'],
  },
  'humidity': {
    'min': 80.0,
    'minDurationHours': 6.0,
    'note': 'Valor fictício de teste',
    'sourceIds': ['test-src-1'],
  },
  'precipitation': {
    'minAmountMm': 1.0,
    'periodHours': 24.0,
    'condition': 'favorable',
    'sourceIds': ['test-src-2'],
  },
  'leafWetness': {
    'minDurationHours': 6.0,
    'optimalDurationHours': 10.0,
    'condition': 'Condição fictícia de teste',
    'sourceIds': ['test-src-1'],
  },
  'dewPoint': {
    'maxDepression': 2.0,
    'sourceIds': ['test-src-2'],
  },
  'degreeDays': {
    'baseTemperature': 10.0,
    'upperThreshold': 32.0,
    'thresholds': [
      {'accumulated': 150.0, 'stage': 'estágio de teste'},
    ],
    'sourceIds': ['test-src-2'],
  },
  'wind': {
    'minSpeed': 5.0,
    'maxSpeed': 40.0,
    'sourceIds': ['test-src-2'],
  },
  'phenology': {
    'susceptibleStages': ['R1', 'R5'],
    'sourceIds': ['test-src-1'],
  },
  'additionalCriteria': [
    {'description': 'Critério adicional fictício', 'sourceIds': ['test-src-1']},
  ],
  'sources': [
    {
      'id': 'test-src-1',
      'title': 'Fonte fictícia 1 (teste)',
      'institution': 'Instituição Fictícia',
      'authors': ['Autor Fictício'],
      'url': 'https://example.org/test-source-1',
      'year': 2020,
      'note': 'Somente para testes',
      'reviewedAt': '2026-10-01',
    },
    {
      'id': 'test-src-2',
      'title': 'Fonte fictícia 2 (teste)',
      'url': 'https://example.org/test-source-2',
    },
  ],
  'lastReviewedAt': '2026-10-01',
  'available': true,
  'confidence': 'moderate',
};

/// Regra fictícia com só alguns critérios.
const Map<String, dynamic> partialRuleJson = {
  'id': 'test-insect-b',
  'organismName': 'Inseto de Teste B',
  'organismType': 'inseto',
  'temperature': {'min': 15.0, 'sourceIds': ['test-src']},
  'sources': [
    {
      'id': 'test-src',
      'title': 'Fonte fictícia (teste)',
      'url': 'https://example.org/test-source',
    },
  ],
  'available': true,
};

/// Organismo cadastrado sem nenhum parâmetro (evidência insuficiente).
const Map<String, dynamic> noParametersRuleJson = {
  'id': 'test-bacterium-c',
  'organismName': 'Bactéria de Teste C',
  'organismType': 'bacterium',
  'available': false,
  'unavailabilityReason': 'Sem evidência (dado de teste)',
};

String rulesFile(List<Map<String, dynamic>> rules, {int schemaVersion = 1}) =>
    jsonEncode({'schemaVersion': schemaVersion, 'rules': rules});
