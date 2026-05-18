/// Utilitário de formatação de datas para o AgroAdvisor.
///
/// Centraliza o padrão DD/MM/YYYY HH:mm evitando duplicação nas telas.
class DateFormatter {
  DateFormatter._();

  /// Retorna a data no formato brasileiro: DD/MM/YYYY HH:mm
  static String format(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} $h:$min';
  }

  /// Retorna apenas a data: DD/MM/YYYY
  static String formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }
}
