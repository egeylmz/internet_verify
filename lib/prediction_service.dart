import 'package:flutter/material.dart';
import 'dart:math' as math;

// --- Paket Bilgisi ---
class PackageInfo {
  final double quotaMb;
  final int billingDay;

  const PackageInfo({required this.quotaMb, required this.billingDay});

  DateTime get currentPeriodStart {
    final now = DateTime.now();
    if (now.day >= billingDay) {
      return DateTime(now.year, now.month, billingDay);
    }
    final year  = now.month == 1 ? now.year - 1 : now.year;
    final month = now.month == 1 ? 12 : now.month - 1;
    return DateTime(year, month, billingDay);
  }

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
  final int daysRemainingOptimistic;   // az kullanım → internet daha geç biter
  final int daysRemainingPessimistic;  // çok kullanım → internet daha erken biter
  final DateTime estimatedExhaustionDate;
  final double averageDailyMB;
  final double trendFactor;
  final double longTermDrift;     // aylık kayma (1.0=sabit, 1.05=ayda %5 artış)
  final double dailyVolatility;  // günlük std dev (MB)
  final List<double> dowAveragesMB;
  final double remainingMB;
  final double usedMB;
  final double quotaMB;
  final int dataPointCount; // analiz edilen toplam gün sayısı

  const PredictionResult({
    required this.daysRemaining,
    required this.daysRemainingOptimistic,
    required this.daysRemainingPessimistic,
    required this.estimatedExhaustionDate,
    required this.averageDailyMB,
    required this.trendFactor,
    required this.longTermDrift,
    required this.dailyVolatility,
    required this.dowAveragesMB,
    required this.remainingMB,
    required this.usedMB,
    required this.quotaMB,
    required this.dataPointCount,
  });

  double get usedPercent =>
      quotaMB > 0 ? (usedMB / quotaMB).clamp(0.0, 1.0) : 0.0;

  // "X–Y gün" — kötümser önce (daha az gün), iyimser sonra (daha çok gün)
  String get scenarioRange =>
      '$daysRemainingPessimistic–$daysRemainingOptimistic gün';

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

  Color get quotaColor {
    if (usedPercent > 0.85) return Colors.redAccent;
    if (usedPercent > 0.65) return Colors.orange;
    return Colors.indigo;
  }
}

// --- Tahmin Motoru ---
class PredictionService {
  // EWMA'da yeni veriye verilen ağırlık (0=hepsi geçmiş, 1=sadece son değer)
  static const double _ewmaAlpha = 0.25;

  static PredictionResult? predict(
    List<Map<String, dynamic>> history,
    PackageInfo packageInfo,
  ) {
    if (history.isEmpty) return null;

    final records = history
        .map((r) => _Record(
              date: DateTime.parse(r['date'] as String),
              mobileMB: (r['mobile_mb'] as num).toDouble(),
            ))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (records.isEmpty) return null;

    // --- 1. DoW grupları: aykırı değer temizle + EWMA ---
    final dowValues = <int, List<double>>{
      for (int i = 1; i <= 7; i++) i: [],
    };
    for (final r in records) {
      dowValues[r.date.weekday]!.add(r.mobileMB);
    }

    final allClean = _removeOutliers(records.map((r) => r.mobileMB).toList());
    final overallAvg = allClean.isEmpty ? 0.0 : _mean(allClean);

    // Her haftanın günü için: aykırı değerleri at, kalan listeye EWMA uygula
    final dowAveragesMB = List.generate(7, (i) {
      final dow = i + 1;
      final clean = _removeOutliers(dowValues[dow]!);
      return clean.isEmpty ? overallAvg : _ewma(clean, _ewmaAlpha);
    });

    // --- 2. Volatilite (günlük std dev) ---
    final dailyVolatility =
        allClean.length > 1 ? _stdDev(allClean, overallAvg) : 0.0;

    // --- 3. Kısa vadeli trend (son 14 gün vs önceki 14 gün) ---
    double trendFactor = 1.0;
    if (records.length >= 14) {
      final recentAvg = _mean(_removeOutliers(
        records.sublist(records.length - 14).map((r) => r.mobileMB).toList(),
      ));
      if (records.length >= 28) {
        final prevAvg = _mean(_removeOutliers(
          records
              .sublist(records.length - 28, records.length - 14)
              .map((r) => r.mobileMB)
              .toList(),
        ));
        if (prevAvg > 0) {
          trendFactor = (recentAvg / prevAvg).clamp(0.5, 2.0);
        }
      }
    }

    // --- 4. Uzun vadeli aylık kayma (doğrusal regresyon) ---
    final longTermDrift = _computeLongTermDrift(records);

    // --- 5. Fatura dönemi faz katsayıları ---
    final phaseMultipliers =
        _computePhaseMultipliers(records, packageInfo, overallAvg);

    // --- 6. Mevcut dönem kullanımı ---
    final periodStart = packageInfo.currentPeriodStart;
    final usedMB = records
        .where((r) => !r.date.isBefore(periodStart))
        .map((r) => r.mobileMB)
        .fold(0.0, (a, b) => a + b);

    final remainingMB =
        (packageInfo.quotaMb - usedMB).clamp(0.0, packageInfo.quotaMb);

    // --- 7. Üç senaryo projeksiyonu ---
    final today = DateTime.now();

    int project(double volatilityShift) {
      if (remainingMB <= 0) return 0;
      double cumulative = 0.0;
      for (int i = 1; i <= 365; i++) {
        final futureDate = today.add(Duration(days: i));
        final cycleDay = _cycleDayOf(futureDate, packageInfo.billingDay);
        final base = dowAveragesMB[futureDate.weekday - 1];
        final predicted =
            (base * trendFactor * phaseMultipliers[_phaseOf(cycleDay)] +
                    volatilityShift)
                .clamp(0.0, double.infinity);
        cumulative += predicted;
        if (cumulative >= remainingMB) return i;
      }
      return 365;
    }

    final daysExpected    = project(0.0);
    final daysOptimistic  = project(-0.67 * dailyVolatility);
    final daysPessimistic = project( 0.67 * dailyVolatility);

    return PredictionResult(
      daysRemaining: daysExpected,
      daysRemainingOptimistic: daysOptimistic,
      daysRemainingPessimistic: daysPessimistic,
      estimatedExhaustionDate: today.add(Duration(days: daysExpected)),
      averageDailyMB: overallAvg,
      trendFactor: trendFactor,
      longTermDrift: longTermDrift,
      dailyVolatility: dailyVolatility,
      dowAveragesMB: dowAveragesMB,
      remainingMB: remainingMB,
      usedMB: usedMB,
      quotaMB: packageInfo.quotaMb,
      dataPointCount: records.length,
    );
  }

  // IQR yöntemi ile aykırı değer temizleme
  static List<double> _removeOutliers(List<double> values) {
    if (values.length < 4) return values;
    final sorted = [...values]..sort();
    final q1 = sorted[(sorted.length * 0.25).floor()];
    final q3 = sorted[((sorted.length * 0.75).ceil())
        .clamp(0, sorted.length - 1)];
    final iqr = q3 - q1;
    if (iqr == 0) return values;
    final lo = q1 - 1.5 * iqr;
    final hi = q3 + 1.5 * iqr;
    return values.where((v) => v >= lo && v <= hi).toList();
  }

  // Üstel ağırlıklı ortalama — değerler kronolojik sırada olmalı
  static double _ewma(List<double> values, double alpha) {
    if (values.isEmpty) return 0.0;
    double s = values.first;
    for (int i = 1; i < values.length; i++) {
      s = alpha * values[i] + (1 - alpha) * s;
    }
    return s;
  }

  static double _mean(List<double> values) =>
      values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;

  static double _stdDev(List<double> values, double mean) {
    if (values.length < 2) return 0.0;
    final variance = values
            .map((v) => math.pow(v - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        (values.length - 1);
    return math.sqrt(variance);
  }

  // Aylık ortalamaların doğrusal regresyonu → aylık kayma faktörü
  static double _computeLongTermDrift(List<_Record> records) {
    if (records.length < 60) return 1.0;

    final buckets = <String, List<double>>{};
    for (final r in records) {
      final key =
          '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}';
      buckets.putIfAbsent(key, () => []).add(r.mobileMB);
    }

    final sortedKeys = buckets.keys.toList()..sort();
    if (sortedKeys.length < 2) return 1.0;

    final monthlyAvgs = sortedKeys
        .map((k) => _mean(_removeOutliers(buckets[k]!)))
        .toList();

    final n = monthlyAvgs.length;
    final xMean = (n - 1) / 2.0;
    final yMean = _mean(monthlyAvgs);
    if (yMean == 0) return 1.0;

    double num = 0.0, den = 0.0;
    for (int i = 0; i < n; i++) {
      num += (i - xMean) * (monthlyAvgs[i] - yMean);
      den += math.pow(i - xMean, 2);
    }
    if (den == 0) return 1.0;

    final slope = num / den; // MB/ay değişim
    return (1.0 + slope / yMean).clamp(0.5, 2.0);
  }

  // Fatura dönemi faz katsayıları: gün 1-10 / 11-20 / 21+
  static List<double> _computePhaseMultipliers(
    List<_Record> records,
    PackageInfo packageInfo,
    double overallAvg,
  ) {
    if (overallAvg == 0) return [1.0, 1.0, 1.0];

    final phaseTotals = [0.0, 0.0, 0.0];
    final phaseCounts = [0, 0, 0];

    for (final r in records) {
      final phase = _phaseOf(_cycleDayOf(r.date, packageInfo.billingDay));
      phaseTotals[phase] += r.mobileMB;
      phaseCounts[phase]++;
    }

    return List.generate(3, (i) {
      if (phaseCounts[i] == 0) return 1.0;
      return ((phaseTotals[i] / phaseCounts[i]) / overallAvg).clamp(0.5, 2.0);
    });
  }

  // Fatura dönemindeki gün numarası (1-tabanlı)
  static int _cycleDayOf(DateTime date, int billingDay) {
    if (date.day >= billingDay) return date.day - billingDay + 1;
    final daysInPrevMonth = DateTime(date.year, date.month, 0).day;
    return daysInPrevMonth - billingDay + date.day + 1;
  }

  // Gün → Faz (0=erken 1-10, 1=orta 11-20, 2=geç 21+)
  static int _phaseOf(int cycleDay) {
    if (cycleDay <= 10) return 0;
    if (cycleDay <= 20) return 1;
    return 2;
  }
}

class _Record {
  final DateTime date;
  final double mobileMB;
  _Record({required this.date, required this.mobileMB});
}
