import 'weather_forecast.dart';

/// Motivos pelos quais a previsão pode estar indisponível.
enum WeatherFailureReason {
  /// Coordenadas ausentes, fora do intervalo válido ou (0, 0).
  invalidLocation,

  /// Sem conexão com a internet / host inacessível.
  noConnection,

  /// A API não respondeu dentro do tempo limite.
  timeout,

  /// Limite de requisições da API atingido (HTTP 429).
  rateLimited,

  /// Erro no servidor da API (HTTP 5xx).
  serviceUnavailable,

  /// Requisição recusada pela API (HTTP 4xx, exceto 429).
  invalidRequest,

  /// Resposta recebida, mas com JSON inválido ou estrutura incompleta.
  invalidResponse,

  /// Falha não prevista — capturada para não derrubar o app.
  unknown,
}

/// Resultado de uma consulta meteorológica.
///
/// O serviço nunca lança exceção para a interface: sempre devolve
/// [WeatherSuccess] ou [WeatherFailure].
sealed class WeatherResult {
  const WeatherResult();
}

class WeatherSuccess extends WeatherResult {
  final WeatherForecast forecast;

  /// true quando a consulta falhou e foi devolvida uma previsão antiga do
  /// cache. A interface deve exibir [WeatherForecast.fetchedAt] nesse caso.
  final bool isStale;

  const WeatherSuccess(this.forecast, {this.isStale = false});
}

class WeatherFailure extends WeatherResult {
  final WeatherFailureReason reason;

  /// Mensagem em português, adequada para exibição ao usuário.
  final String message;

  const WeatherFailure(this.reason, this.message);

  @override
  String toString() => 'WeatherFailure($reason): $message';
}
