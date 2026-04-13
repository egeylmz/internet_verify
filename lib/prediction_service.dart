import 'package:flutter/material.dart';

// --- Paket Bilgisi ---
class PackageInfo {
  final double quotaMb;   // Toplam paket boyutu (MB)
  final int billingDay;   // Fatura günü (1-31)

  const PackageInfo({required this.quotaMb, required this.billingDay});

  // Mevcut fatura döneminin başlangıç tarihi
  DateTime get currentPeriodStart {
    final now = DateTime.now();
    if (now.day >= billingDay) {
      return DateTime(now.year, now.month, billingDay);
    }
    // Önceki ay (Ocak → Aralık geçişi dahil)
    final year  = now.month == 1 ? now.year - 1 : now.year;
    final month = now.month == 1 ? 12 : now.month - 1;
    return DateTime(year, month, billingDay);
  }

  // Bir sonraki yenileme tarihi
  DateTime get nextRenewalDate {
    final now = DateTime.now();
    if (now.day < billingDay) {
      return DateTime(now.year, now.month, billingDay);
    }
    final year  = now.month == 12 ? now.year + 1 : now.year;
    final month = now.month == 12 ? 1 : now.month + 1;
    return DateTime(year, month, billingDay);
  }
}

// --- Tahmin Sonucu ---
class PredictionResult {
  final int daysRemaining;
  final DateTime estimatedExhaustionDate;
  final double averageDailyMB;
  final double trendFactor;           // 1.0 = stabil, >1.0 = artıyor
  final List<double> dowAveragesMB;   // [0]=Pzt … [6]=Paz
  final double remainingMB;
  final double usedMB;
  final double quotaMB;

  const PredictionResult({
    required this.daysRemaining,
    required this.estimatedExhaustionDate,
    required this.averageDailyMB,
    required this.trendFactor,
    required this.dowAveragesMB,
    required this.remainingMB,
    required this.usedMB,
    required this.quotaMB,
  });

  double get usedPercent =>
      quotaMB > 0 ? (usedMB / quotaMB).clamp(0.0, 1.0) : 0.0;

  String get trendLabel {
    if (trendFactor > 1.1) return 'Artıyor';
    if (trendFactor < 0.9) return 'Azalıyor';
    return 'Stabil';
  }

  IconData get trendIcon {
    if (trendFactor > 1.1) return Icons.trending_up_rounded;
    if (trendFactor < 0.9) return Icons.trending_down_rounded;
    return Icons.trending_flat_rounded;
  }

  Color get trendColor {
    if (trendFactor > 1.1) return Colors.redAccent;
    if (trendFactor < 0.9) return Colors.green;
    return Colors.orange;
  }

  // Kota doluluk rengini döndür
  Color get quotaColor {
    if (usedPercent > 0.85) return Colors.redAccent;
    if (usedPercent > 0.65) return Colors.orange;
    return Colors.indigo;
  }
}

// --- Tahmin Motoru ---
class PredictionService {
  static PredictionResult? predict(
    List<Map<String, dynamic>> history,
    PackageInfo packageInfo,
  ) {
    if (history.isEmpty) return null;

    // Kayıtları parse et ve tarihe göre sırala
    final records = history
        .map((r) => _Record(
              date: DateTime.parse(r['date'] as String),
              mobileMB: (r['mobile_mb'] as num).toDouble(),
            ))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (records.isEmpty) return null;

    // --- Haftanın günü ortalamaları (1=Pzt, 7=Paz) ---
    final dowTotals = <int, double>{for (int i = 1; i <= 7; i++) i: 0.0};
    final dowCounts = <int, int>{for (int i = 1; i <= 7; i++) i: 0};

    for (final r in records) {
      final dow = r.date.weekday;
      dowTotals[dow] = dowTotals[dow]! + r.mobileMB;
      dowCounts[dow] = dowCounts[dow]! + 1;
    }

    final overallAvg = records.map((r) => r.mobileMB).reduce((a, b) => a + b) /
        records.length;

    // dowAveragesMB[0]=Pzt … [6]=Paz
    final dowAveragesMB = List.generate(7, (i) {
      final dow = i + 1;
      final count = dowCounts[dow]!;
      return count > 0 ? dowTotals[dow]! / count : overallAvg;
    });

    // --- Trend: son 14 gün vs önceki 14 gün ---
    double trendFactor = 1.0;
    if (records.length >= 14) {
      final recentSum = records
          .sublist(records.length - 14)
          .map((r) => r.mobileMB)
          .reduce((a, b) => a + b);
      final recentAvg = recentSum / 14;

      if (records.length >= 28) {
        final prevSum = records
            .sublist(records.length - 28, records.length - 14)
            .map((r) => r.mobileMB)
            .reduce((a, b) => a + b);
        final prevAvg = prevSum / 14;
        if (prevAvg > 0) {
          trendFactor = (recentAvg / prevAvg).clamp(0.5, 2.0);
        }
      }
    }

    // --- Mevcut dönem kullanımı ---
    final periodStart = packageInfo.currentPeriodStart;
    final usedMB = records
        .where((r) => !r.date.isBefore(periodStart))
        .map((r) => r.mobileMB)
        .fold(0.0, (a, b) => a + b);

    final remainingMB =
        (packageInfo.quotaMb - usedMB).clamp(0.0, packageInfo.quotaMb);

    // --- Kota bitişini tahmin et ---
    final today = DateTime.now();
    int daysRemaining = 0;

    if (remainingMB <= 0) {
      daysRemaining = 0;
    } else {
      double cumulative = 0.0;
      for (int i = 1; i <= 365; i++) {
        final futureDate = today.add(Duration(days: i));
        final predicted = dowAveragesMB[futureDate.weekday - 1] * trendFactor;
        cumulative += predicted;
        if (cumulative >= remainingMB) {
          daysRemaining = i;
          break;
        }
        if (i == 365) daysRemaining = 365;
      }
    }

    return PredictionResult(
      daysRemaining: daysRemaining,
      estimatedExhaustionDate: today.add(Duration(days: daysRemaining)),
      averageDailyMB: overallAvg,
      trendFactor: trendFactor,
      dowAveragesMB: dowAveragesMB,
      remainingMB: remainingMB,
      usedMB: usedMB,
      quotaMB: packageInfo.quotaMb,
    );
  }
}

class _Record {
  final DateTime date;
  final double mobileMB;
  _Record({required this.date, required this.mobileMB});
}
