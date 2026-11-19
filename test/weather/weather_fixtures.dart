import 'dart:convert';

/// Resposta reduzida no formato real do Open-Meteo (campos e unidades
/// conferidos contra a API em 02/10/2026).
///
/// Passa por jsonEncode/jsonDecode para ter os mesmos tipos dinâmicos que
/// uma resposta real decodificada.
Map<String, dynamic> validResponse() =>
    jsonDecode(jsonEncode(_validResponseLiteral)) as Map<String, dynamic>;

const _validResponseLiteral = {
  'latitude': -22.741652,
  'longitude': -47.669098,
  'generationtime_ms': 0.26,
  'utc_offset_seconds': -10800,
  'timezone': 'America/Sao_Paulo',
  'timezone_abbreviation': 'GMT-3',
  'elevation': 527.0,
  'current_units': {
    'time': 'iso8601',
    'interval': 'seconds',
    'temperature_2m': '°C',
    'relative_humidity_2m': '%',
    'precipitation': 'mm',
    'wind_speed_10m': 'km/h',
  },
  'current': {
    'time': '2026-10-02T12:30',
    'interval': 900,
    'temperature_2m': 21.3,
    'relative_humidity_2m': 82,
    'precipitation': 0.10,
    'wind_speed_10m': 6.3,
  },
  'hourly_units': {
    'time': 'iso8601',
    'temperature_2m': '°C',
    'relative_humidity_2m': '%',
    'precipitation': 'mm',
    'precipitation_probability': '%',
    'wind_speed_10m': 'km/h',
  },
  'hourly': {
    'time': ['2026-10-02T00:00', '2026-10-02T01:00', '2026-10-02T02:00'],
    'temperature_2m': [17.2, 17.0, 16.8],
    'relative_humidity_2m': [90, 92, 95],
    'precipitation': [0.0, 0.2, 0.0],
    'precipitation_probability': [10, 20, 35],
    'wind_speed_10m': [5.1, 4.8, 3.9],
  },
  'daily_units': {
    'time': 'iso8601',
    'temperature_2m_max': '°C',
    'temperature_2m_min': '°C',
    'precipitation_sum': 'mm',
    'precipitation_probability_max': '%',
  },
  'daily': {
    'time': ['2026-10-02', '2026-10-03'],
    'temperature_2m_max': [22.3, 22.8],
    'temperature_2m_min': [17.2, 16.1],
    'precipitation_sum': [1.30, 17.20],
    'precipitation_probability_max': [59, 94],
  },
};

String validResponseBody() => jsonEncode(validResponse());
