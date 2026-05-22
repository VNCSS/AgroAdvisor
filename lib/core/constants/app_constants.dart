/// Constantes globais do AgroAdvisor.
///
/// Centralize aqui qualquer valor "mágico" para facilitar manutenção.
/// NUNCA use números ou strings literais espalhados pelo código — referencie
/// esta classe.
class AppConstants {
  AppConstants._();

  // ─── Imagens ────────────────────────────────────────────────────────────────

  /// Qualidade JPEG aplicada ao picker (0-100). Reduz o tamanho do base64.
  static const int imageQuality = 40;

  /// Largura máxima da imagem redimensionada pelo picker (px).
  static const double imageMaxWidth = 800;

  // ─── Radar / Mapa ────────────────────────────────────────────────────────────

  /// Quantas ocorrências mais próximas são exibidas no mapa.
  static const int radarNearestCount = 8;

  /// Coordenada padrão do mapa quando a localização não está disponível (Brasília).
  static const double defaultLatitude = -15.793889;
  static const double defaultLongitude = -47.882778;

  // ─── Alertas ─────────────────────────────────────────────────────────────────

  /// Raio mínimo configurável para alertas de pragas (km).
  static const double alertRadiusMin = 5.0;

  /// Raio máximo configurável para alertas de pragas (km).
  static const double alertRadiusMax = 100.0;

  /// Raio padrão ao criar um novo usuário (km).
  static const double alertRadiusDefault = 20.0;

  /// Número de divisões do Slider de raio na tela de configurações.
  static const int alertRadiusSliderDivisions = 19;

  // ─── IA / Gemini ─────────────────────────────────────────────────────────────

  /// Chave de API do Google Gemini.
  ///
  /// ⚠️  SEGURANÇA: Em produção, mova esta chave para uma variável de ambiente
  /// (--dart-define=GEMINI_API_KEY=...) ou proxie via Cloud Function para que
  /// ela nunca fique exposta no binário do app.
  static const String geminiApiKey = 'AIzaSyBHU1lj6zKoWek0hrmzz3XCr85RRvgN4Es';

  /// Endpoint do Gemini 2.0 Flash para análise de imagens.
  static const String geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  /// Timeout para chamadas à API de IA (segundos).
  static const int aiTimeoutSeconds = 30;

  // ─── Firestore — nomes das coleções ──────────────────────────────────────────

  static const String colProperties = 'properties';
  static const String colOccurrences = 'occurrences';
  static const String colUsers = 'users';

  // ─── Notificações ─────────────────────────────────────────────────────────────

  static const String notifChannelId = 'agro_advisor_pest_alerts';
  static const String notifChannelName = 'Alertas de Pragas';
  static const String notifChannelDescription =
      'Notificações sobre pragas detectadas próximas à sua propriedade';

  // ─── Culturas disponíveis ─────────────────────────────────────────────────────

  static const List<String> availableCrops = [
    'Milho',
    'Soja',
    'Café',
    'Cana-de-açúcar',
    'Algodão',
    'Trigo',
    'Arroz',
    'Feijão',
    'Outro',
  ];
}
