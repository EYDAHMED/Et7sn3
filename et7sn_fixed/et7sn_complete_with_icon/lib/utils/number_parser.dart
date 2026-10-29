/// Parses numbers typed with Western or Arabic-Indic digits and a dot / comma /
/// Arabic decimal separator. Returns null if it isn't a valid number.
double? parseLocalizedNumber(String raw) {
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final ch in raw.trim().split('')) {
    final i = arabicDigits.indexOf(ch);
    if (i >= 0) {
      buffer.write(i);
    } else if (ch == '٫' || ch == ',') {
      buffer.write('.');
    } else {
      buffer.write(ch);
    }
  }
  return double.tryParse(buffer.toString());
}
