
void main() {
  final String sampleText = """
GPRS internet.04 10/03/2026 06:24:58 336845026 0.000000
GPRS internet.21 10/03/2026 06:24:58 1370282 0.000000
GPRS internet.18 10/03/2026 06:29:49 116849 0.000000
GPRS internet.23 10/03/2026 06:44:46 61369038 0.000000
Telefon Görüşmeleri 905054686993 10/03/2026 09:35:24 00:00:46 0.000000
""";

  final RegExp dataRegExp = RegExp(
    r'GPRS\s+internet[\d.]*\s+(\d{2})/(\d{2})/(\d{4})\s+(\d{2}:\d{2}):\d{2}\s+(\d+)',
    caseSensitive: false,
  );

  final matches = dataRegExp.allMatches(sampleText);
  print("Found ${matches.length} matches.");
  
  double totalBytes = 0;
  for (var match in matches) {
    print("Matched: ${match.group(0)} | Bytes: ${match.group(5)}");
    totalBytes += double.parse(match.group(5)!);
  }
  
  print("Total Bytes: $totalBytes");
  print("Total MB: ${totalBytes / (1024 * 1024)}");
}
