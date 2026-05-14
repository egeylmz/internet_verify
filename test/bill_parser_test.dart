import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Turkcell Parser Calculation Test from Image Data', () {
    // Verilen Turkcell fatura görselindeki veriler (Tarih, Miktar, Birim)
    final rawData = """
    09 Mart, 20:18 internet 1189.11 Kb
    09 Mart, 19:39 X(Twitter) 26384.82 Kb
    09 Mart, 19:14 Facebook 1387.96 Kb
    09 Mart, 19:01 internet 122533.68 Kb
    09 Mart, 16:14 Facebook 4915.72 Kb
    09 Mart, 16:11 X(Twitter) 32328.96 Kb
    09 Mart, 16:02 internet 6914.96 Kb
    09 Mart, 15:12 E-mail 236.23 Kb
    09 Mart, 15:08 internet 1287.79 Kb
    09 Mart, 14:33 Facebook 11.85 Kb
    09 Mart, 14:26 internet 2574.9 Kb
    09 Mart, 14:23 X(Twitter) 14.07 Kb
    09 Mart, 14:02 E-mail 239.58 Kb
    09 Mart, 13:31 E-mail 80.19 Kb
    09 Mart, 13:18 Facebook 166.93 Kb
    09 Mart, 13:17 X(Twitter) 37.33 Kb
    09 Mart, 12:41 Turkcell TV+ 1169.97 Kb
    09 Mart, 12:26 internet 37306.47 Kb
    09 Mart, 12:14 X(Twitter) 3158.81 Kb
    09 Mart, 12:07 Turkcell TV+ 756.85 Kb
    09 Mart, 11:36 internet 111333.1 Kb
    09 Mart, 11:31 Turkcell TV+ 75.42 Kb
    """;

    final RegExp dataRegExp = RegExp(r"([\d.]+)\s+(Kb|Mb|Gb)");
    double totalMB = 0;

    for (var match in dataRegExp.allMatches(rawData)) {
      final double amount = double.parse(match.group(1)!);
      final String unit = match.group(2)!;
      
      if (unit == 'Kb') {
        totalMB += amount / 1024;
      } else if (unit == 'Mb') {
        totalMB += amount;
      } else if (unit == 'Gb') {
        totalMB += amount * 1024;
        test('Türk Telekom Parser Calculation Test from Image Data', () {
    // Verilen Türk Telekom fatura görselindeki veriler (Görüşme Tipi, Aranan Numara, Tarih-Saat, Byte)
    final rawData = """
    GPRS  internet.04  10/03/2026 06:24:58  336845026  0.000000
    GPRS  internet.21  10/03/2026 06:24:58  1370282  0.000000
    GPRS  internet.18  10/03/2026 06:29:49  116849  0.000000
    GPRS  internet.23  10/03/2026 06:44:46  61369038  0.000000
    GPRS  internet.15  10/03/2026 07:37:40  700601  0.000000
    GPRS  internet.18  10/03/2026 07:55:25  12041265  0.000000
    GPRS  internet.04  10/03/2026 08:24:58  27507968  0.000000
    GPRS  internet.21  10/03/2026 08:24:58  15683345  0.000000
    GPRS  internet.23  10/03/2026 08:44:46  86350444  0.000000
    Telefon Görüşmeleri  905054686993  10/03/2026 09:35:24  00:00:46  0.000000
    GPRS  internet.15  10/03/2026 09:37:41  5553647  0.000000
    GPRS  internet.18  10/03/2026 09:55:25  377487526  0.000000
    GPRS  internet.22  10/03/2026 10:14:49  59048  0.000000
    GPRS  internet.04  10/03/2026 10:24:58  65897863  0.000000
    GPRS  internet.21  10/03/2026 10:24:58  18772982  0.000000
    GPRS  internet.23  10/03/2026 10:44:46  76529226  0.000000
    GPRS  internet.15  10/03/2026 11:37:41  9734985  0.000000
    GPRS  internet.18  10/03/2026 11:43:56  108684047  0.000000
    GPRS  internet.22  10/03/2026 12:02:47  30948  0.000000
    """;

    final RegExp dataRegExp = RegExp(
      r'GPRS\s+internet[\d.]*\s+(\d{2})/(\d{2})/(\d{4})\s+(\d{2}:\d{2}):\d{2}\s+(\d+)',
      caseSensitive: false,
    );
    double totalMB = 0;

    for (var match in dataRegExp.allMatches(rawData)) {
      final double bytes = double.parse(match.group(5)!);
      totalMB += bytes / 1048576.0;
    }

    print("Total Calculated Türk Telekom MB: ${totalMB.toStringAsFixed(2)} MB");
    
    // El ile hesaplama doğrulaması:
    // Toplam Byte = 1188812090
    // 1188812090 / 1048576 = 1133.7392482757568 MB
    
    expect(totalMB, closeTo(1133.74, 0.01));
  });
}
      test('Türk Telekom Parser Calculation Test from Image Data', () {
    // Verilen Türk Telekom fatura görselindeki veriler (Görüşme Tipi, Aranan Numara, Tarih-Saat, Byte)
    final rawData = """
    GPRS  internet.04  10/03/2026 06:24:58  336845026  0.000000
    GPRS  internet.21  10/03/2026 06:24:58  1370282  0.000000
    GPRS  internet.18  10/03/2026 06:29:49  116849  0.000000
    GPRS  internet.23  10/03/2026 06:44:46  61369038  0.000000
    GPRS  internet.15  10/03/2026 07:37:40  700601  0.000000
    GPRS  internet.18  10/03/2026 07:55:25  12041265  0.000000
    GPRS  internet.04  10/03/2026 08:24:58  27507968  0.000000
    GPRS  internet.21  10/03/2026 08:24:58  15683345  0.000000
    GPRS  internet.23  10/03/2026 08:44:46  86350444  0.000000
    Telefon Görüşmeleri  905054686993  10/03/2026 09:35:24  00:00:46  0.000000
    GPRS  internet.15  10/03/2026 09:37:41  5553647  0.000000
    GPRS  internet.18  10/03/2026 09:55:25  377487526  0.000000
    GPRS  internet.22  10/03/2026 10:14:49  59048  0.000000
    GPRS  internet.04  10/03/2026 10:24:58  65897863  0.000000
    GPRS  internet.21  10/03/2026 10:24:58  18772982  0.000000
    GPRS  internet.23  10/03/2026 10:44:46  76529226  0.000000
    GPRS  internet.15  10/03/2026 11:37:41  9734985  0.000000
    GPRS  internet.18  10/03/2026 11:43:56  108684047  0.000000
    GPRS  internet.22  10/03/2026 12:02:47  30948  0.000000
    """;

    final RegExp dataRegExp = RegExp(
      r'GPRS\s+internet[\d.]*\s+(\d{2})/(\d{2})/(\d{4})\s+(\d{2}:\d{2}):\d{2}\s+(\d+)',
      caseSensitive: false,
    );
    double totalMB = 0;

    for (var match in dataRegExp.allMatches(rawData)) {
      final double bytes = double.parse(match.group(5)!);
      totalMB += bytes / 1048576.0;
    }

    print("Total Calculated Türk Telekom MB: ${totalMB.toStringAsFixed(2)} MB");
    
    // El ile hesaplama doğrulaması:
    // Toplam Byte = 1188812090
    // 1188812090 / 1048576 = 1133.7392482757568 MB
    
    expect(totalMB, closeTo(1133.74, 0.01));
  });
}

    print("Total Calculated MB: ${totalMB.toStringAsFixed(2)} MB");
    
    // El ile hesaplama doğrulaması:
    // 1189.11 + 26384.82 + 1387.96 + 122533.68 + 4915.72 + 32328.96 + 6914.96 + 236.23 + 1287.79 + 11.85 + 2574.9 + 14.07 + 239.58 + 80.19 + 166.93 + 37.33 + 1169.97 + 37306.47 + 3158.81 + 756.85 + 111333.1 + 75.42 
    // = 354090.73 Kb
    // 354090.73 / 1024 = 345.791728515625 MB
    
    expect(totalMB, closeTo(345.79, 0.01));
  });

  test('Drift Logic Sign and Color Test', () {
    // Senaryo 1: Fatura > Cihaz (Sapma +, Kırmızı)
    double billUsage = 350.0;
    double deviceUsage = 300.0;
    double delta = billUsage - deviceUsage;
    String sign = delta > 0 ? "+" : "";
    bool isRed = delta > 0;
    double percent = (delta.abs() / deviceUsage) * 100;

    expect(sign, "+");
    expect(isRed, true);
    expect(percent, closeTo(16.66, 0.01));

    // Senaryo 2: Cihaz > Fatura (Sapma -, Yeşil)
    billUsage = 300.0;
    deviceUsage = 350.0;
    delta = billUsage - deviceUsage;
    sign = delta > 0 ? "+" : ""; // - işareti String.format veya formatUsage içinde yönetilecek
    bool isGreen = delta < 0;
    percent = (delta.abs() / deviceUsage) * 100;

    expect(sign, "");
    expect(isGreen, true);
    expect(percent, closeTo(14.28, 0.01));
  });
  test('Türk Telekom Parser Calculation Test from Image Data', () {
    // Verilen Türk Telekom fatura görselindeki veriler (Görüşme Tipi, Aranan Numara, Tarih-Saat, Byte)
    final rawData = """
    GPRS  internet.04  10/03/2026 06:24:58  336845026  0.000000
    GPRS  internet.21  10/03/2026 06:24:58  1370282  0.000000
    GPRS  internet.18  10/03/2026 06:29:49  116849  0.000000
    GPRS  internet.23  10/03/2026 06:44:46  61369038  0.000000
    GPRS  internet.15  10/03/2026 07:37:40  700601  0.000000
    GPRS  internet.18  10/03/2026 07:55:25  12041265  0.000000
    GPRS  internet.04  10/03/2026 08:24:58  27507968  0.000000
    GPRS  internet.21  10/03/2026 08:24:58  15683345  0.000000
    GPRS  internet.23  10/03/2026 08:44:46  86350444  0.000000
    Telefon Görüşmeleri  905054686993  10/03/2026 09:35:24  00:00:46  0.000000
    GPRS  internet.15  10/03/2026 09:37:41  5553647  0.000000
    GPRS  internet.18  10/03/2026 09:55:25  377487526  0.000000
    GPRS  internet.22  10/03/2026 10:14:49  59048  0.000000
    GPRS  internet.04  10/03/2026 10:24:58  65897863  0.000000
    GPRS  internet.21  10/03/2026 10:24:58  18772982  0.000000
    GPRS  internet.23  10/03/2026 10:44:46  76529226  0.000000
    GPRS  internet.15  10/03/2026 11:37:41  9734985  0.000000
    GPRS  internet.18  10/03/2026 11:43:56  108684047  0.000000
    GPRS  internet.22  10/03/2026 12:02:47  30948  0.000000
    """;

    final RegExp dataRegExp = RegExp(
      r'GPRS\s+internet[\d.]*\s+(\d{2})/(\d{2})/(\d{4})\s+(\d{2}:\d{2}):\d{2}\s+(\d+)',
      caseSensitive: false,
    );
    double totalMB = 0;

    for (var match in dataRegExp.allMatches(rawData)) {
      final double bytes = double.parse(match.group(5)!);
      totalMB += bytes / 1048576.0;
    }

    print("Total Calculated Türk Telekom MB: ${totalMB.toStringAsFixed(2)} MB");
    
    // El ile hesaplama doğrulaması:
    // Toplam Byte = 1188812090
    // 1188812090 / 1048576 = 1133.7392482757568 MB
    
    expect(totalMB, closeTo(1133.74, 0.01));
  });
}
