// Formatação em português usada nas explicações do motor.
//
// Duplicada propositalmente de DashboardFormat para manter o domínio
// independente da camada de apresentação.

/// Número com vírgula decimal; inteiros sem casas ("6,2", "90").
String fmtNum(double v, {int decimals = 1}) {
  if (v == v.roundToDouble()) return v.round().toString();
  return v.toStringAsFixed(decimals).replaceAll('.', ',');
}

String fmtKm(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${fmtNum(km)} km';
}

/// "hoje", "ontem" ou "há N dias", por diferença de datas de calendário.
String fmtDaysAgo(DateTime date, DateTime now) {
  final d = DateTime(date.year, date.month, date.day);
  final t = DateTime(now.year, now.month, now.day);
  final diff = t.difference(d).inDays;
  if (diff <= 0) return 'hoje';
  if (diff == 1) return 'ontem';
  return 'há $diff dias';
}

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Faixa legível: "18–26 °C", "≥ 80 %", "≤ 30 km/h". null se ambos null.
String? fmtRange(double? min, double? max, String unit) {
  if (min != null && max != null) {
    return '${fmtNum(min)}–${fmtNum(max)} $unit';
  }
  if (min != null) return '≥ ${fmtNum(min)} $unit';
  if (max != null) return '≤ ${fmtNum(max)} $unit';
  return null;
}
