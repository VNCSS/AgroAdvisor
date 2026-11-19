import 'dart:async';
import 'dart:convert';

import 'package:agro_advisor/features/property/domain/property_model.dart';
import 'package:agro_advisor/features/weather/data/weather_repository.dart';
import 'package:agro_advisor/features/weather/domain/weather_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'weather_fixtures.dart';

http.Response _json(String body, int status) => http.Response.bytes(
      utf8.encode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  late int calls;
  late DateTime now;

  setUp(() {
    calls = 0;
    now = DateTime(2026, 10, 2, 12);
  });

  WeatherRepository repoWith(
    Future<http.Response> Function(http.Request) handler, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    return WeatherRepository(
      client: MockClient((req) {
        calls++;
        return handler(req);
      }),
      timeout: timeout,
      cacheTtl: const Duration(minutes: 60),
      now: () => now,
    );
  }

  Future<WeatherResult> fetch(WeatherRepository repo, {bool force = false}) =>
      repo.getForecast(latitude: -22.7317, longitude: -47.6483, forceRefresh: force);

  group('requisição', () {
    test('envia coordenadas arredondadas e apenas as variáveis necessárias', () async {
      late Uri uri;
      final repo = repoWith((req) async {
        uri = req.url;
        return _json(validResponseBody(), 200);
      });

      await fetch(repo);

      final q = uri.queryParameters;
      expect(q['latitude'], '-22.73');
      expect(q['longitude'], '-47.65');
      expect(q['timezone'], 'auto');
      expect(q['current'], 'temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m');
      expect(q['hourly'],
          'temperature_2m,relative_humidity_2m,precipitation,precipitation_probability,wind_speed_10m');
      expect(q['daily'],
          'temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max');
    });

    test('getForecastForProperty usa as coordenadas cadastradas', () async {
      late Uri uri;
      final repo = repoWith((req) async {
        uri = req.url;
        return _json(validResponseBody(), 200);
      });
      const property = PropertyModel(
        id: 'p1', name: 'Sítio', mainCrop: 'Soja',
        latitude: -15.601, longitude: -56.097, ownerId: 'u1',
      );

      final result = await repo.getForecastForProperty(property);

      expect(result, isA<WeatherSuccess>());
      expect(uri.queryParameters['latitude'], '-15.6');
      expect(uri.queryParameters['longitude'], '-56.1');
    });
  });

  group('localização inválida', () {
    for (final (lat, lng) in [
      (0.0, 0.0),
      (91.0, -47.0),
      (-22.0, 181.0),
      (double.nan, -47.0),
      (-22.0, double.infinity),
    ]) {
      test('($lat, $lng) → invalidLocation sem chamar a API', () async {
        final repo = repoWith((_) async => _json(validResponseBody(), 200));

        final result = await repo.getForecast(latitude: lat, longitude: lng);

        expect(result, isA<WeatherFailure>());
        expect((result as WeatherFailure).reason, WeatherFailureReason.invalidLocation);
        expect(calls, 0);
      });
    }
  });

  group('tratamento de erros', () {
    Future<WeatherFailureReason> reasonFor(
      Future<http.Response> Function(http.Request) handler, {
      Duration timeout = const Duration(seconds: 5),
    }) async {
      final result = await fetch(repoWith(handler, timeout: timeout));
      expect(result, isA<WeatherFailure>());
      return (result as WeatherFailure).reason;
    }

    test('sem conexão → noConnection', () async {
      expect(
        await reasonFor((_) async => throw http.ClientException('Failed host lookup')),
        WeatherFailureReason.noConnection,
      );
    });

    test('timeout → timeout', () async {
      expect(
        await reasonFor(
          (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return _json(validResponseBody(), 200);
          },
          timeout: const Duration(milliseconds: 20),
        ),
        WeatherFailureReason.timeout,
      );
    });

    test('HTTP 429 → rateLimited', () async {
      expect(await reasonFor((_) async => _json('{"error":true,"reason":"limit"}', 429)),
          WeatherFailureReason.rateLimited);
    });

    test('HTTP 503 → serviceUnavailable', () async {
      expect(await reasonFor((_) async => _json('oops', 503)),
          WeatherFailureReason.serviceUnavailable);
    });

    test('HTTP 400 → invalidRequest', () async {
      expect(
        await reasonFor((_) async =>
            _json('{"error":true,"reason":"Latitude must be in range"}', 400)),
        WeatherFailureReason.invalidRequest,
      );
    });

    test('JSON inválido → invalidResponse', () async {
      expect(await reasonFor((_) async => _json('{nao é json', 200)),
          WeatherFailureReason.invalidResponse);
    });

    test('JSON raiz que não é objeto → invalidResponse', () async {
      expect(await reasonFor((_) async => _json('[1,2,3]', 200)),
          WeatherFailureReason.invalidResponse);
    });

    test('resposta incompleta (sem hourly) → invalidResponse', () async {
      final body = jsonEncode(validResponse()..remove('hourly'));
      expect(await reasonFor((_) async => _json(body, 200)),
          WeatherFailureReason.invalidResponse);
    });

    test('erro inesperado → unknown', () async {
      expect(await reasonFor((_) async => throw StateError('falha')),
          WeatherFailureReason.unknown);
    });
  });

  group('cache', () {
    test('segunda consulta dentro da validade não chama a API', () async {
      final repo = repoWith((_) async => _json(validResponseBody(), 200));

      await fetch(repo);
      now = now.add(const Duration(minutes: 59));
      final second = await fetch(repo);

      expect(calls, 1);
      expect((second as WeatherSuccess).isStale, isFalse);
    });

    test('coordenadas próximas (mesmo arredondamento) compartilham cache', () async {
      final repo = repoWith((_) async => _json(validResponseBody(), 200));

      await repo.getForecast(latitude: -22.7311, longitude: -47.6512);
      await repo.getForecast(latitude: -22.7349, longitude: -47.6458);

      expect(calls, 1);
    });

    test('cache vencido faz nova consulta', () async {
      final repo = repoWith((_) async => _json(validResponseBody(), 200));

      await fetch(repo);
      now = now.add(const Duration(minutes: 60));
      await fetch(repo);

      expect(calls, 2);
    });

    test('forceRefresh ignora cache válido', () async {
      final repo = repoWith((_) async => _json(validResponseBody(), 200));

      await fetch(repo);
      await fetch(repo, force: true);

      expect(calls, 2);
    });

    test('falha com cache vencido devolve previsão antiga marcada como stale', () async {
      var fail = false;
      final repo = repoWith((_) async {
        if (fail) throw http.ClientException('offline');
        return _json(validResponseBody(), 200);
      });

      final first = await fetch(repo) as WeatherSuccess;
      fail = true;
      now = now.add(const Duration(hours: 3));
      final second = await fetch(repo);

      expect(second, isA<WeatherSuccess>());
      expect((second as WeatherSuccess).isStale, isTrue);
      expect(second.forecast.fetchedAt, first.forecast.fetchedAt);
    });

    test('falha não é armazenada em cache', () async {
      var fail = true;
      final repo = repoWith((_) async {
        if (fail) return _json('erro', 500);
        return _json(validResponseBody(), 200);
      });

      expect(await fetch(repo), isA<WeatherFailure>());
      fail = false;
      expect(await fetch(repo), isA<WeatherSuccess>());
      expect(calls, 2);
    });

    test('consultas simultâneas ao mesmo ponto geram uma única requisição', () async {
      final gate = Completer<void>();
      final repo = repoWith((_) async {
        await gate.future;
        return _json(validResponseBody(), 200);
      });

      final a = fetch(repo);
      final b = fetch(repo);
      gate.complete();
      final results = await Future.wait([a, b]);

      expect(calls, 1);
      expect(results.every((r) => r is WeatherSuccess), isTrue);
    });
  });
}
