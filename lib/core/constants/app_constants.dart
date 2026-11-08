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

  /// Idade máxima (dias) de uma ocorrência para gerar alerta de proximidade.
  /// Evita notificar todo o histórico da região no primeiro login.
  /// Valor de projeto.
  static const int nearbyAlertMaxAgeDays = 7;

  /// Número de divisões do Slider de raio na tela de configurações.
  static const int alertRadiusSliderDivisions = 19;

  // ─── IA / Google Gemini ──────────────────────────────────────────────────────

  /// Chave de API do Google Gemini (AI Studio).
  ///
  /// ⚠️  SEGURANÇA: Em produção, passe via --dart-define=GEMINI_API_KEY=AIza...
  /// para que a chave nunca seja embutida no binário. Exemplos:
  ///   flutter run --dart-define=GEMINI_API_KEY=AIza...
  ///   flutter build apk --dart-define=GEMINI_API_KEY=AIza...
  ///
  /// Obtenha sua chave gratuita em: https://aistudio.google.com/apikey
  /// Tier gratuito: 1.500 requisições/dia — suficiente para desenvolvimento.
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Endpoint REST do Gemini 2.5 Flash (multimodal, suporta imagens).
  ///
  /// A chave é passada como query param ?key=... (diferente do Claude,
  /// que usa header 'x-api-key').
  static const String geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  /// Timeout para chamadas à API de IA (segundos).
  static const int aiTimeoutSeconds = 30;

  // ─── Clima / Open-Meteo ──────────────────────────────────────────────────────

  /// Endpoint de previsão do Open-Meteo (sem chave de API).
  /// Uso gratuito não comercial; exige atribuição "Open-Meteo.com" (CC BY 4.0).
  static const String openMeteoEndpoint = 'https://api.open-meteo.com/v1/forecast';

  /// Timeout para chamadas à API meteorológica (segundos).
  static const int weatherTimeoutSeconds = 15;

  /// Validade do cache em memória da previsão (minutos).
  /// Valor de projeto: a previsão do Open-Meteo é atualizada em intervalos de horas.
  static const int weatherCacheMinutes = 60;

  /// Quantidade de dias de previsão solicitados.
  static const int weatherForecastDays = 7;

  /// Casas decimais das coordenadas enviadas à API (2 casas ≈ 1,1 km).
  /// Reduz a precisão exposta a terceiros e permite reaproveitar o cache.
  static const int weatherCoordinateDecimals = 2;

  // ─── Dashboard da propriedade ────────────────────────────────────────────────

  /// Janela de ocorrências regionais considerada no dashboard (dias).
  /// Valor de projeto; múltiplo de 7 para a distribuição semanal.
  static const int dashboardWindowDays = 28;

  /// Quantas ocorrências recentes são listadas no dashboard.
  static const int dashboardRecentCount = 3;

  /// Quantos organismos aparecem no ranking "mais registrados".
  static const int dashboardTopOrganisms = 5;

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
