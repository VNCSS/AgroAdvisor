import 'package:agro_advisor/features/weather/domain/weather_forecast.dart';
import 'package:flutter_test/flutter_test.dart';

import 'weather_fixtures.dart';

void main() {
  final fetchedAt = DateTime(2026, 10, 2, 12);

  group('WeatherForecast.fromMap', () {
    test('converte resposta completa', () {
      final f = WeatherForecast.fromMap(validResponse(), fetchedAt: fetchedAt);

      expect(f.latitude, -22.741652);
      expect(f.longitude, -47.669098);
      expect(f.elevation, 527.0);
      expect(f.timezone, 'America/Sao_Paulo');
      expect(f.fetchedAt, fetchedAt);

      expect(f.current, isNotNull);
      expect(f.current!.time, DateTime(2026, 10, 2, 12, 30));
      expect(f.current!.temperature, 21.3);
      expect(f.current!.relativeHumidity, 82);
      expect(f.current!.precipitation, 0.1);
      expect(f.current!.windSpeed, 6.3);

      expect(f.hourly.times, hasLength(3));
      expect(f.hourly.times.first, DateTime(2026, 10, 2, 0));
      expect(f.hourly.valuesOf(HourlyVariable.temperature), [17.2, 17.0, 16.8]);
      expect(f.hourly.valuesOf(HourlyVariable.precipitationProbability), [10, 20, 35]);

      expect(f.daily, hasLength(2));
      expect(f.daily[1].date, DateTime(2026, 10, 3));
      expect(f.daily[1].temperatureMax, 22.8);
      expect(f.daily[1].temperatureMin, 16.1);
      expect(f.daily[1].precipitationSum, 17.2);
      expect(f.daily[1].precipitationProbabilityMax, 94);
    });

    test('mantém null para valores ausentes e calcula cobertura', () {
      final map = validResponse();
      (map['hourly'] as Map)['relative_humidity_2m'] = [80, null, 'x'];

      final f = WeatherForecast.fromMap(map, fetchedAt: fetchedAt);

      expect(f.hourly.valuesOf(HourlyVariable.relativeHumidity), [80, null, null]);
      expect(f.hourly.coverage(HourlyVariable.relativeHumidity), closeTo(1 / 3, 1e-9));
      expect(f.hourly.coverage(HourlyVariable.temperature), 1.0);
    });

    test('variável horária ausente vira série de nulls com cobertura 0', () {
      final map = validResponse();
      (map['hourly'] as Map).remove('wind_speed_10m');

      final f = WeatherForecast.fromMap(map, fetchedAt: fetchedAt);

      expect(f.hourly.valuesOf(HourlyVariable.windSpeed), [null, null, null]);
      expect(f.hourly.coverage(HourlyVariable.windSpeed), 0.0);
    });

    test('blocos current e daily ausentes não geram erro', () {
      final map = validResponse()
        ..remove('current')
        ..remove('daily');

      final f = WeatherForecast.fromMap(map, fetchedAt: fetchedAt);

      expect(f.current, isNull);
      expect(f.daily, isEmpty);
    });

    test('campo diário ausente vira null', () {
      final map = validResponse();
      (map['daily'] as Map).remove('precipitation_sum');

      final f = WeatherForecast.fromMap(map, fetchedAt: fetchedAt);

      expect(f.daily.every((d) => d.precipitationSum == null), isTrue);
      expect(f.daily.first.temperatureMax, 22.3);
    });

    test('sem coordenadas lança FormatException', () {
      final map = validResponse()..remove('latitude');
      expect(() => WeatherForecast.fromMap(map, fetchedAt: fetchedAt),
          throwsFormatException);
    });

    test('sem bloco hourly lança FormatException', () {
      final map = validResponse()..remove('hourly');
      expect(() => WeatherForecast.fromMap(map, fetchedAt: fetchedAt),
          throwsFormatException);
    });

    test('hourly sem lista de horários lança FormatException', () {
      final map = validResponse();
      (map['hourly'] as Map).remove('time');
      expect(() => WeatherForecast.fromMap(map, fetchedAt: fetchedAt),
          throwsFormatException);
    });

    test('horário inválido lança FormatException', () {
      final map = validResponse();
      (map['hourly'] as Map)['time'] = ['2026-10-02T00:00', 'ontem', '2026-10-02T02:00'];
      expect(() => WeatherForecast.fromMap(map, fetchedAt: fetchedAt),
          throwsFormatException);
    });

    test('série com tamanho diferente dos horários lança FormatException', () {
      final map = validResponse();
      (map['hourly'] as Map)['temperature_2m'] = [17.2, 17.0];
      expect(() => WeatherForecast.fromMap(map, fetchedAt: fetchedAt),
          throwsFormatException);
    });
  });
}
