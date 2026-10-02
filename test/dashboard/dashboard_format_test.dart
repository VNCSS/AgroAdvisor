import 'package:agro_advisor/features/dashboard/presentation/dashboard_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('número com vírgula e ausência como "—"', () {
    expect(DashboardFormat.number(21.34), '21,3');
    expect(DashboardFormat.number(82, decimals: 0), '82');
    expect(DashboardFormat.number(null), '—');
    expect(DashboardFormat.number(double.nan), '—');
  });

  test('unidade só é exibida quando há valor', () {
    expect(DashboardFormat.withUnit(6.3, 'km/h'), '6,3 km/h');
    expect(DashboardFormat.withUnit(null, 'km/h'), '—');
    expect(DashboardFormat.withUnit(0, 'mm'), '0,0 mm');
  });

  test('distância em metros abaixo de 1 km', () {
    expect(DashboardFormat.distance(0.45), '450 m');
    expect(DashboardFormat.distance(3.25), '3,3 km');
  });

  test('rótulos de dia', () {
    final today = DateTime(2026, 10, 2, 15); // sexta-feira
    expect(DashboardFormat.dayLabel(DateTime(2026, 10, 2), today), 'Hoje');
    expect(DashboardFormat.dayLabel(DateTime(2026, 10, 3), today), 'Amanhã');
    expect(DashboardFormat.dayLabel(DateTime(2026, 10, 4), today), 'Dom');
    expect(DashboardFormat.dayMonth(DateTime(2026, 1, 5)), '05/01');
  });

  test('dias atrás', () {
    final now = DateTime(2026, 10, 2, 9);
    expect(DashboardFormat.daysAgo(DateTime(2026, 10, 2, 1), now), 'hoje');
    expect(DashboardFormat.daysAgo(DateTime(2026, 10, 1, 23), now), 'ontem');
    expect(DashboardFormat.daysAgo(DateTime(2026, 9, 25), now), 'há 7 dias');
  });
}
