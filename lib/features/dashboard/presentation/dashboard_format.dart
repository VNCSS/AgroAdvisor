/// Formatação de valores exibidos no dashboard (padrão brasileiro).
///
/// Valores ausentes são exibidos como "—" — nunca como zero.
class DashboardFormat {
  DashboardFormat._();

  static const String missing = '—';

  static const _weekdays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

  /// Número com vírgula decimal, ou "—" se null.
  static String number(double? v, {int decimals = 1}) {
    if (v == null || !v.isFinite) return missing;
    return v.toStringAsFixed(decimals).replaceAll('.', ',');
  }

  /// Número com unidade ("21,3 °C"), ou "—" se null.
  static String withUnit(double? v, String unit, {int decimals = 1}) {
    final n = number(v, decimals: decimals);
    return n == missing ? missing : '$n $unit';
  }

  /// Distância: metros abaixo de 1 km, quilômetros acima.
  static String distance(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${number(km)} km';
  }

  /// "Hoje", "Amanhã" ou abreviação do dia da semana.
  static String dayLabel(DateTime date, DateTime today) {
    final d = DateTime(date.year, date.month, date.day);
    final t = DateTime(today.year, today.month, today.day);
    final diff = d.difference(t).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Amanhã';
    return _weekdays[date.weekday % 7];
  }

  /// "dd/mm".
  static String dayMonth(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

  /// "HH:mm".
  static String time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  /// "hoje", "ontem" ou "há N dias".
  static String daysAgo(DateTime date, DateTime now) {
    final d = DateTime(date.year, date.month, date.day);
    final t = DateTime(now.year, now.month, now.day);
    final diff = t.difference(d).inDays;
    if (diff <= 0) return 'hoje';
    if (diff == 1) return 'ontem';
    return 'há $diff dias';
  }
}
