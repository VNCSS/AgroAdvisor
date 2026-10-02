import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../property/domain/property_model.dart';
import '../domain/weather_forecast.dart';
import '../domain/weather_result.dart';

/// Repositório meteorológico baseado na API Open-Meteo.
///
/// - Usa as coordenadas já cadastradas da propriedade (não consulta o GPS).
/// - Nunca lança exceção: devolve sempre um [WeatherResult].
/// - Mantém cache em memória por coordenada arredondada, válido por
///   [AppConstants.weatherCacheMinutes]. Em caso de falha, devolve a última
///   previsão conhecida marcada como desatualizada ([WeatherSuccess.isStale]).
class WeatherRepository {
  final http.Client _client;
  final Uri _endpoint;
  final Duration _timeout;
  final Duration _cacheTtl;
  final DateTime Function() _now;

  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future<WeatherResult>> _inFlight = {};

  WeatherRepository({
    http.Client? client,
    Uri? endpoint,
    Duration? timeout,
    Duration? cacheTtl,
    DateTime Function()? now,
  })  : _client = client ?? http.Client(),
        _endpoint = endpoint ?? Uri.parse(AppConstants.openMeteoEndpoint),
        _timeout = timeout ??
            const Duration(seconds: AppConstants.weatherTimeoutSeconds),
        _cacheTtl = cacheTtl ??
            const Duration(minutes: AppConstants.weatherCacheMinutes),
        _now = now ?? DateTime.now;

  /// Previsão para a localização cadastrada da propriedade.
  Future<WeatherResult> getForecastForProperty(
    PropertyModel property, {
    bool forceRefresh = false,
  }) {
    return getForecast(
      latitude: property.latitude,
      longitude: property.longitude,
      forceRefresh: forceRefresh,
    );
  }

  /// Previsão para as coordenadas informadas.
  ///
  /// [forceRefresh] ignora o cache válido (ex.: "puxar para atualizar").
  Future<WeatherResult> getForecast({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    if (!isValidCoordinate(latitude, longitude)) {
      dev.log('[WeatherRepository] coordenadas inválidas: $latitude, $longitude');
      return const WeatherFailure(
        WeatherFailureReason.invalidLocation,
        'Localização da propriedade ausente ou inválida. '
        'Revise as coordenadas no cadastro da propriedade.',
      );
    }

    final lat = _round(latitude);
    final lng = _round(longitude);
    final key = '$lat,$lng';

    final cached = _cache[key];
    if (!forceRefresh && cached != null && !_isExpired(cached)) {
      dev.log('[WeatherRepository] cache válido para $key');
      return WeatherSuccess(cached.forecast);
    }

    // Evita requisições duplicadas simultâneas para o mesmo ponto.
    final pending = _inFlight[key];
    if (pending != null) return pending;

    final future = _fetchAndCache(key, lat, lng, cached);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Coordenada válida: finita, dentro do intervalo geográfico e diferente
  /// de (0, 0) — valor que os modelos do app produzem quando o campo falta.
  static bool isValidCoordinate(double latitude, double longitude) {
    if (!latitude.isFinite || !longitude.isFinite) return false;
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    if (latitude == 0 && longitude == 0) return false;
    return true;
  }

  /// Descarta o cache (ex.: ao sair da conta).
  void clearCache() => _cache.clear();

  // ── Internos ────────────────────────────────────────────────────────────────

  Future<WeatherResult> _fetchAndCache(
    String key,
    double lat,
    double lng,
    _CacheEntry? previous,
  ) async {
    final result = await _fetch(lat, lng);

    if (result is WeatherSuccess) {
      _cache[key] = _CacheEntry(result.forecast, _now());
      return result;
    }

    if (previous != null) {
      dev.log('[WeatherRepository] falha ($result) — usando cache antigo');
      return WeatherSuccess(previous.forecast, isStale: true);
    }
    return result;
  }

  Future<WeatherResult> _fetch(double lat, double lng) async {
    final uri = _endpoint.replace(queryParameters: {
      'latitude': lat.toString(),
      'longitude': lng.toString(),
      'current': CurrentWeather.apiFields.join(','),
      'hourly': HourlyVariable.values.map((v) => v.apiName).join(','),
      'daily': DailyWeather.apiFields.join(','),
      'forecast_days': AppConstants.weatherForecastDays.toString(),
      'timezone': 'auto',
    });

    try {
      dev.log('[WeatherRepository] consultando Open-Meteo para $lat, $lng');
      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        // bodyBytes + utf8 garante a leitura correta de unidades como "°C".
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('JSON raiz não é um objeto');
        }
        final forecast = WeatherForecast.fromMap(decoded, fetchedAt: _now());
        dev.log('[WeatherRepository] previsão recebida '
            '(${forecast.hourly.times.length} horas, ${forecast.daily.length} dias)');
        return WeatherSuccess(forecast);
      }

      dev.log('[WeatherRepository] HTTP ${response.statusCode}: ${_apiReason(response)}');

      if (response.statusCode == 429) {
        return const WeatherFailure(
          WeatherFailureReason.rateLimited,
          'Limite de consultas meteorológicas atingido. Tente novamente mais tarde.',
        );
      }
      if (response.statusCode >= 500) {
        return const WeatherFailure(
          WeatherFailureReason.serviceUnavailable,
          'Serviço meteorológico indisponível no momento.',
        );
      }
      return WeatherFailure(
        WeatherFailureReason.invalidRequest,
        'Consulta meteorológica recusada (HTTP ${response.statusCode}).',
      );
    } on TimeoutException {
      dev.log('[WeatherRepository] timeout após ${_timeout.inSeconds}s');
      return const WeatherFailure(
        WeatherFailureReason.timeout,
        'O serviço meteorológico demorou para responder.',
      );
    } on http.ClientException catch (e) {
      dev.log('[WeatherRepository] falha de conexão: $e');
      return const WeatherFailure(
        WeatherFailureReason.noConnection,
        'Sem conexão com a internet para obter a previsão do tempo.',
      );
    } on FormatException catch (e) {
      dev.log('[WeatherRepository] resposta inválida: ${e.message}');
      return const WeatherFailure(
        WeatherFailureReason.invalidResponse,
        'Resposta do serviço meteorológico incompleta ou inválida.',
      );
    } catch (e, st) {
      dev.log('[WeatherRepository] erro inesperado', error: e, stackTrace: st);
      return const WeatherFailure(
        WeatherFailureReason.unknown,
        'Não foi possível obter a previsão do tempo.',
      );
    }
  }

  bool _isExpired(_CacheEntry entry) =>
      _now().difference(entry.storedAt) >= _cacheTtl;

  static double _round(double v) =>
      double.parse(v.toStringAsFixed(AppConstants.weatherCoordinateDecimals));

  /// O Open-Meteo devolve erros como {"error": true, "reason": "..."}.
  static String _apiReason(http.Response response) {
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is Map && json['reason'] is String) return json['reason'] as String;
    } catch (_) {}
    return 'sem detalhes';
  }
}

class _CacheEntry {
  final WeatherForecast forecast;
  final DateTime storedAt;
  const _CacheEntry(this.forecast, this.storedAt);
}
