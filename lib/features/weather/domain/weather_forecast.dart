/// Variáveis horárias solicitadas ao Open-Meteo.
///
/// Contém apenas o que é usado hoje (exibição de condições e previsão).
/// Novas variáveis (ex.: dew_point_2m) devem ser adicionadas somente quando
/// uma funcionalidade realmente as consumir.
enum HourlyVariable {
  temperature('temperature_2m'),
  relativeHumidity('relative_humidity_2m'),
  precipitation('precipitation'),
  precipitationProbability('precipitation_probability'),
  windSpeed('wind_speed_10m');

  const HourlyVariable(this.apiName);

  /// Nome do parâmetro na API do Open-Meteo.
  final String apiName;
}

/// Condições meteorológicas no momento da consulta (bloco `current`).
///
/// Unidades padrão do Open-Meteo: °C, %, mm, km/h.
/// Qualquer valor pode ser null se a API não o retornar.
class CurrentWeather {
  final DateTime time;
  final double? temperature;
  final double? relativeHumidity;
  final double? precipitation;
  final double? windSpeed;

  const CurrentWeather({
    required this.time,
    this.temperature,
    this.relativeHumidity,
    this.precipitation,
    this.windSpeed,
  });

  static const List<String> apiFields = [
    'temperature_2m',
    'relative_humidity_2m',
    'precipitation',
    'wind_speed_10m',
  ];

  factory CurrentWeather.fromMap(Map<String, dynamic> map) {
    final time = _parseTime(map['time']);
    if (time == null) {
      throw const FormatException('Bloco current sem horário válido');
    }
    return CurrentWeather(
      time: time,
      temperature: _toDouble(map['temperature_2m']),
      relativeHumidity: _toDouble(map['relative_humidity_2m']),
      precipitation: _toDouble(map['precipitation']),
      windSpeed: _toDouble(map['wind_speed_10m']),
    );
  }
}

/// Resumo diário da previsão (bloco `daily`).
class DailyWeather {
  final DateTime date;
  final double? temperatureMax;
  final double? temperatureMin;
  final double? precipitationSum;
  final double? precipitationProbabilityMax;

  const DailyWeather({
    required this.date,
    this.temperatureMax,
    this.temperatureMin,
    this.precipitationSum,
    this.precipitationProbabilityMax,
  });

  static const List<String> apiFields = [
    'temperature_2m_max',
    'temperature_2m_min',
    'precipitation_sum',
    'precipitation_probability_max',
  ];
}

/// Série horária: um horário por posição e uma lista de valores por variável.
///
/// Valores ausentes na resposta da API ficam como null — nunca são preenchidos.
class HourlyWeather {
  final List<DateTime> times;
  final Map<HourlyVariable, List<double?>> _values;

  HourlyWeather({
    required this.times,
    required Map<HourlyVariable, List<double?>> values,
  }) : _values = values;

  /// Valores da variável, alinhados com [times].
  /// Se a variável não veio na resposta, retorna uma lista só de nulls.
  List<double?> valuesOf(HourlyVariable variable) =>
      _values[variable] ?? List<double?>.filled(times.length, null);

  /// Fração (0.0–1.0) de horários com valor presente para a variável.
  double coverage(HourlyVariable variable) {
    if (times.isEmpty) return 0.0;
    final present = valuesOf(variable).where((v) => v != null).length;
    return present / times.length;
  }
}

/// Previsão meteorológica completa de um ponto, já convertida e validada.
///
/// Horários estão no fuso local do ponto consultado (timezone=auto),
/// representados como "hora de parede" — sem conversão para o fuso do aparelho.
class WeatherForecast {
  /// Coordenadas do ponto de grade usado pelo Open-Meteo (podem diferir
  /// levemente das coordenadas solicitadas).
  final double latitude;
  final double longitude;
  final double? elevation;
  final String timezone;

  /// Momento em que a resposta foi obtida da API.
  final DateTime fetchedAt;

  final CurrentWeather? current;
  final HourlyWeather hourly;
  final List<DailyWeather> daily;

  const WeatherForecast({
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.fetchedAt,
    required this.hourly,
    required this.daily,
    this.elevation,
    this.current,
  });

  /// Converte a resposta JSON do Open-Meteo.
  ///
  /// Lança [FormatException] quando a estrutura obrigatória (coordenadas e
  /// bloco hourly com horários) está ausente ou inconsistente.
  /// Blocos opcionais ausentes (current, daily, variáveis) não geram erro.
  factory WeatherForecast.fromMap(
    Map<String, dynamic> map, {
    required DateTime fetchedAt,
  }) {
    final lat = _toDouble(map['latitude']);
    final lng = _toDouble(map['longitude']);
    if (lat == null || lng == null) {
      throw const FormatException('Resposta sem coordenadas');
    }

    final hourlyRaw = map['hourly'];
    if (hourlyRaw is! Map) {
      throw const FormatException('Resposta sem bloco hourly');
    }
    final hourlyMap = Map<String, dynamic>.from(hourlyRaw);
    final hourlyTimes = _parseTimeList(hourlyMap['time'], 'hourly');

    final values = <HourlyVariable, List<double?>>{};
    for (final variable in HourlyVariable.values) {
      final raw = hourlyMap[variable.apiName];
      if (raw == null) continue; // variável não retornada → tratada como ausente
      values[variable] =
          _parseNumberList(raw, hourlyTimes.length, variable.apiName);
    }

    final currentRaw = map['current'];
    final current = currentRaw is Map
        ? CurrentWeather.fromMap(Map<String, dynamic>.from(currentRaw))
        : null;

    final dailyRaw = map['daily'];
    final daily = dailyRaw is Map
        ? _parseDaily(Map<String, dynamic>.from(dailyRaw))
        : const <DailyWeather>[];

    return WeatherForecast(
      latitude: lat,
      longitude: lng,
      elevation: _toDouble(map['elevation']),
      timezone: map['timezone'] as String? ?? '',
      fetchedAt: fetchedAt,
      current: current,
      hourly: HourlyWeather(times: hourlyTimes, values: values),
      daily: daily,
    );
  }

  static List<DailyWeather> _parseDaily(Map<String, dynamic> map) {
    final dates = _parseTimeList(map['time'], 'daily');
    final columns = <String, List<double?>>{};
    for (final field in DailyWeather.apiFields) {
      final raw = map[field];
      columns[field] = raw == null
          ? List<double?>.filled(dates.length, null)
          : _parseNumberList(raw, dates.length, field);
    }
    return [
      for (var i = 0; i < dates.length; i++)
        DailyWeather(
          date: dates[i],
          temperatureMax: columns['temperature_2m_max']![i],
          temperatureMin: columns['temperature_2m_min']![i],
          precipitationSum: columns['precipitation_sum']![i],
          precipitationProbabilityMax: columns['precipitation_probability_max']![i],
        ),
    ];
  }
}

// ── Helpers de conversão ──────────────────────────────────────────────────────

double? _toDouble(dynamic v) {
  if (v is num && v.isFinite) return v.toDouble();
  return null;
}

DateTime? _parseTime(dynamic v) => v is String ? DateTime.tryParse(v) : null;

List<DateTime> _parseTimeList(dynamic raw, String block) {
  if (raw is! List) {
    throw FormatException('Bloco $block sem lista de horários');
  }
  return raw.map((v) {
    final t = _parseTime(v);
    if (t == null) throw FormatException('Horário inválido em $block: $v');
    return t;
  }).toList();
}

List<double?> _parseNumberList(dynamic raw, int expectedLength, String field) {
  if (raw is! List) {
    throw FormatException('Campo $field não é uma lista');
  }
  if (raw.length != expectedLength) {
    throw FormatException(
      'Campo $field com ${raw.length} valores (esperado $expectedLength)',
    );
  }
  return raw.map(_toDouble).toList();
}
