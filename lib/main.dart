import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'database_helper.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';


void main() {
  runApp(const DataVerifyApp());
}

class DataVerifyApp extends StatelessWidget {
  const DataVerifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verifyte', // Başlık güncellendi
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.indigo),
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final List<Widget> _pages = [const DashboardPage(), const StatisticsPage(), const VerifyPage(), const SuggestionPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Özet'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_graph_rounded), label: 'İstatistik'),
          BottomNavigationBarItem(icon: Icon(Icons.fact_check_rounded), label: 'Doğrulama'),
          BottomNavigationBarItem(icon: Icon(Icons.tips_and_updates_rounded), label: 'Öneri'),
        ],
      ),
    );
  }
}

// --- SEKME 1: DASHBOARD ---
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const platform = MethodChannel('com.example.internet_verify');
  Map<dynamic, dynamic> _allUsageSummary = {
    '1h_mobile': 0.0, '1h_wifi': 0.0, '1d_mobile': 0.0, '1d_wifi': 0.0,
    '1w_mobile': 0.0, '1w_wifi': 0.0, '1m_mobile': 0.0, '1m_wifi': 0.0,
  };
  List<dynamic> _appUsageList = [];
  bool _isLoading = false;
  String _selectedPeriod = '1d';

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermission().then((_) => _fetchAllData());
  }

  Future<void> _checkAndRequestPermission() async {
    try {
      final bool hasPermission = await platform.invokeMethod('checkPermission');

      if (!hasPermission && mounted) {
        // İzin yoksa kullanıcıya şık bir uyarı göster
        await showDialog(
          context: context,
          barrierDismissible: false, // İzin verilmeden kapatılamasın
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.security_rounded, color: Colors.indigo),
                SizedBox(width: 10),
                Text("İzin Gerekli"),
              ],
            ),
            content: const Text(
              "Uygulamanın veri tüketimini ölçebilmesi için 'Kullanım Verilerine Erişim' izni vermeniz gerekmektedir. Ayarlar sayfasında 'Verifyte' uygulamasını bulup izni aktif edin.",
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await platform.invokeMethod('openSettings');
                  if (mounted) Navigator.pop(context);
                },
                child: const Text("AYARLARA GİT", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("İzin kontrol hatası: $e");
    }
  }


  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    try {
      final Map<dynamic, dynamic> summary = await platform.invokeMethod('getAllUsageData');
      final List<dynamic> usageList = await platform.invokeMethod('getAppUsageList', {'period': _selectedPeriod});

      setState(() {
        _allUsageSummary = summary;
        _appUsageList = usageList;
      });

      // 1. Veritabanındaki satır sayısını kontrol et
      final existingData = await DatabaseHelper.instance.queryAllRows();

      // 2. Eğer veritabanında 2'den az satır varsa (geçmiş aktarılmamış demektir)
      // Bu, sadece bugünün kaydı olsa bile geçmişi zorla çeker.
      if (existingData.length < 2) {
        debugPrint("Veritabanı eksik görünüyor, geçmiş veriler zorla aktarılıyor...");
        final List<dynamic> monthlyHistory = await platform.invokeMethod('getMonthlyDailyUsage');

        for (var day in monthlyHistory) {
          final now = DateTime.now();
          // Kotlin'den gelen "01.04" formatını parçalıyoruz
          final parts = (day['date'] as String).split('.');

          if (parts.length == 2) {
            // "01", "04" gibi kısımları alıp 2026-04-01 formatına getiriyoruz
            final String dayFormatted = parts[0].padLeft(2, '0');
            final String monthFormatted = parts[1].padLeft(2, '0');
            final dateStr = "${now.year}-$monthFormatted-$dayFormatted";

            await DatabaseHelper.instance.insertOrUpdate({
              'date': dateStr,
              'mobile_mb': day['usageMB'] ?? 0.0,
              'wifi_mb': 0.0,
              'day_of_week': _getDayOfWeekFromDate(dateStr),
            });
          }
        }
      }

      final now = DateTime.now();
      final String todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      await DatabaseHelper.instance.insertOrUpdate({
        'date': todayStr,
        'mobile_mb': _allUsageSummary['1d_mobile'] ?? 0.0,
        'wifi_mb': _allUsageSummary['1d_wifi'] ?? 0.0,
        'day_of_week': now.weekday,
      });

      debugPrint("Senkronizasyon tamamlandı.");

    } catch (e) {
      debugPrint("Hata: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  int _getDayOfWeekFromDate(String dateStr) {
    try {
      return DateTime.parse(dateStr).weekday;
    } catch (_) {
      return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Kullanım Detayları'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _isLoading ? null : _fetchAllData)],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildSummaryGrid(),
              _buildComparisonCard(),
              _buildPeriodSelector(),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    Icon(Icons.list_alt_rounded, color: Colors.indigo, size: 22),
                    SizedBox(width: 8),
                    Text('Uygulama Bazlı Tüketim', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              _isLoading
                  ? const Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator())
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _appUsageList.length,
                itemBuilder: (context, index) => _buildAppCard(_appUsageList[index]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        shrinkWrap: true, crossAxisCount: 2, childAspectRatio: 2.1,
        crossAxisSpacing: 12, mainAxisSpacing: 12,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _summaryCard("Son 1 Saat", "${_allUsageSummary['1h_mobile']?.toStringAsFixed(1)} MB", Colors.lightBlue.shade600),
          _summaryCard("Bugün", "${_allUsageSummary['1d_mobile']?.toStringAsFixed(1)} MB", Colors.indigo.shade600),
          _summaryCard("Bu Hafta", "${_allUsageSummary['1w_mobile']?.toStringAsFixed(1)} MB", Colors.deepPurple.shade600),
          _summaryCard("Bu Ay", "${_allUsageSummary['1m_mobile']?.toStringAsFixed(1)} MB", Colors.purple.shade600),
        ],
      ),
    );
  }

  Widget _buildComparisonCard() {
    double mobile = _allUsageSummary['1m_mobile'] ?? 0.0;
    double wifi = _allUsageSummary['1m_wifi'] ?? 0.0;
    double total = mobile + wifi;
    double savingRate = total > 0 ? (wifi / total) : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Aylık Veri Dengesi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: total > 0 ? (wifi / total) : 0,
              minHeight: 10,
              backgroundColor: Colors.orangeAccent.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _indicatorLabel("Wi-Fi", "${wifi.toStringAsFixed(1)} MB", Colors.green),
              _indicatorLabel("Mobil", "${mobile.toStringAsFixed(1)} MB", Colors.orangeAccent),
            ],
          ),
          const Divider(height: 30),
          Text(
            wifi > mobile
                ? "Tebrikler! Verinizin %${(savingRate * 100).toStringAsFixed(0)}'ini Wi-Fi ile kullanarak tasarruf ettiniz."
                : "Uyarı: Mobil veri kullanımınız Wi-Fi'dan daha yüksek.",
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _indicatorLabel(String label, String value, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text("$label: ", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _summaryCard(String title, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = {'1h': '1 Saat', '1d': '1 Gün', '1w': '1 Hafta', '1m': '1 Ay'};
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: periods.entries.map((e) => ChoiceChip(
        label: Text(e.value),
        selected: _selectedPeriod == e.key,
        onSelected: (val) { if(val) { setState(()=> _selectedPeriod = e.key); _fetchAllData(); } },
        selectedColor: Colors.indigo.shade100,
        labelStyle: TextStyle(color: _selectedPeriod == e.key ? Colors.indigo : Colors.black87),
      )).toList(),
    );
  }

  Widget _buildAppCard(dynamic app) {
    final String name = app['appName'] ?? 'Bilinmeyen';
    final Uint8List? iconData = app['iconBytes'] != null && (app['iconBytes'] as List).isNotEmpty
        ? Uint8List.fromList(List<int>.from(app['iconBytes']))
        : null;
    return Card(
      elevation: 0, color: Colors.white, margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: app['iconBytes'] != null
                ? Image.memory(
              app['iconBytes'] as Uint8List, // Kotlin'den gelen bayt dizisi
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Center(child: Text(name[0].toUpperCase())), // Hata olursa harf göster
            )
                : Center(
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text(app['packageName'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1),
        trailing: Text('${(app['usageMB'] as double).toStringAsFixed(1)} MB', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
      ),
    );
  }
}

// --- SEKME 2: İSTATİSTİK ---
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  List<dynamic> _monthlyData = [];
  bool _isLoading = false;

  Color _getBarColor(int index) {
    final List<Color> colors = [
      Colors.blue.shade400,
      Colors.deepPurple.shade400,
      Colors.indigo.shade400,
      Colors.purple.shade400
    ];
    return colors[index % colors.length];
  }

  @override
  void initState() {
    super.initState();
    _fetchMonthlyData();
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _formatFullDate(String dateStr) {
    try {
      DateTime dt = DateTime.parse(dateStr);
      final months = ["", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
      return "${dt.day} ${months[dt.month]} ${dt.year}";
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _fetchMonthlyData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final List<Map<String, dynamic>> allRows = await DatabaseHelper.instance.queryAllRows();

      DateTime now = DateTime.now();
      List<Map<String, dynamic>> last30Days = [];

      for (int i = 29; i >= 0; i--) {
        DateTime targetDate = now.subtract(Duration(days: i));
        String dateKey = "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";

        var existingRows = allRows.where((row) => row['date'] == dateKey).toList();
        double usage = 0.0;

        if (existingRows.isNotEmpty) {
          usage = (existingRows.first['mobile_mb'] as num).toDouble();
        }

        last30Days.add({
          'date': dateKey,
          'usageMB': usage,
        });
      }

      if (mounted) {
        setState(() {
          _monthlyData = last30Days;
        });
      }
    } catch (e) {
      debugPrint("Kritik Veri Hatası: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportCSV() async {
    try {
      final List<Map<String, dynamic>> rows = await DatabaseHelper.instance.queryAllRows();
      if (rows.isEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Henüz kaydedilmiş veri yok.")));
        return;
      }

      List<List<dynamic>> csvData = [
        ["Date", "Mobile_MB", "WiFi_MB", "DayOfWeek"],
        ...rows.map((row) => [row['date'], row['mobile_mb'], row['wifi_mb'], row['day_of_week']])
      ];

      String csvString = const ListToCsvConverter().convert(csvData);
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/usage_data.csv";
      final file = File(path);
      await file.writeAsString(csvString);

      await Share.shareXFiles([XFile(path)], text: 'DataVerify Eğitim Verisi');
    } catch (e) {
      debugPrint("Export hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('30 Günlük Analiz'),
        actions: [
          IconButton(icon: const Icon(Icons.file_download_outlined), onPressed: _exportCSV),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _isLoading ? null : _fetchMonthlyData),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMonthlyData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 30),
              _buildChartArea(),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Divider()),
              _buildDailyList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartArea() {
    if (_monthlyData.isEmpty) return const SizedBox(height: 250, child: Center(child: Text("Veri yok")));

    return SizedBox(
      height: 280, // Tek sayfaya sığması için yüksekliği biraz optimize ettik
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
        child: BarChart(
          BarChartData(
            // Grafik sınırlarını ve kaydırmayı devre dışı bırakıyoruz
            alignment: BarChartAlignment.spaceAround,
            maxY: _monthlyData.map((e) => e['usageMB'] as double).reduce((a, b) => a > b ? a : b) * 1.2,

            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (v, m) => SideTitleWidget(
                    meta: m,
                    child: Text("${v.toInt()}", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1, // Her birimi kontrol et
                    // _buildChartArea içindeki bottomTitles -> SideTitles -> getTitlesWidget kısmı:
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      int total = _monthlyData.length; // Genelde 30
                      if (total == 0) return const SizedBox();

                      // 0, 7, 14, 21, 29 indeksleri (Tam 5 nokta)
                      List<int> points = [0, (total / 4).floor(), (total / 2).floor(), (total * 3 / 4).floor(), total - 1];

                      if (points.contains(index)) {
                        DateTime dt = DateTime.parse(_monthlyData[index]['date']);
                        return SideTitleWidget(
                          meta: meta,
                          child: Text("${dt.day}/${dt.month}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        );
                      }
                      return const SizedBox();
                    }
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: _monthlyData.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: (e.value['usageMB'] as double),
                    color: _getBarColor(e.key),
                    width: 5,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                  )
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _monthlyData.length,
      itemBuilder: (context, index) {
        // Listeyi yeniden eskiye göstermek için ters çeviriyoruz
        final dayData = _monthlyData[_monthlyData.length - 1 - index];
        bool isToday = _isSameDay(DateTime.parse(dayData['date']), DateTime.now());

        return ListTile(
          leading: Icon(Icons.calendar_today, size: 18, color: Colors.indigo.shade300),
          title: Text(
            isToday ? "Bugün" : _formatFullDate(dayData['date']),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          trailing: Text(
            "${(dayData['usageMB']).toStringAsFixed(2)} MB",
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
          ),
        );
      },
    );
  }
}

// --- SEKME 3: DOĞRULAMA (AUDIT) ---
class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  // --- 1. & 2. MADDE: Başlık ve Statü Metinleri ---
  String _status = "Karşılaştırma için operatör PDF dökümanını yükleyin.";
  bool _isProcessing = false;
  Map<String, dynamic>? _resultData;
  double _driftPercent = 0;
  Color _driftColor = Colors.green;

  // --- 4. MADDE: Veri Birimi Dönüştürücü ---
  String _formatUsage(double totalMb) {
    int gb = totalMb ~/ 1024;
    int mb = (totalMb % 1024).toInt();
    int kb = ((totalMb - totalMb.toInt()) * 1024).toInt();

    List<String> parts = [];
    if (gb > 0) parts.add("$gb GB");
    if (mb > 0) parts.add("$mb MB");
    if (kb > 0) parts.add("$kb KB");

    return parts.isEmpty ? "0 KB" : parts.join(", ");
  }

  Future<void> _pickAndProcessPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _isProcessing = true;
          _status = "Veriler karşılaştırılıyor...";
        });

        final Uint8List bytes = result.files.single.bytes!;
        final String extractedText = await compute(_parsePdfInBackground, bytes);

        if (mounted) {
          if (extractedText.trim().isNotEmpty) {
            _analyzeOperatorData(extractedText);
          } else {
            setState(() => _status = "Hata: PDF'ten metin ayıklanamadı.");
          }
        }
      }
    } catch (e) {
      setState(() => _status = "Hata: PDF işlenemedi ($e)");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _analyzeOperatorData(String rawText) {
    final RegExp dataRegExp = RegExp(
      r"(\d{2})\s+([a-zA-ZşŞüÜçÇöÖıİ]+),?\s+(\d{2}:\d{2}).*?([\d.]+)\s+(Kb|Mb|Gb|Sn)",
      dotAll: true,
    );

    final matches = dataRegExp.allMatches(rawText);
    double totalPdfMb = 0;
    DateTime? minDate;
    DateTime? maxDate;

    for (var match in matches) {
      try {
        int day = int.parse(match.group(1)!);
        String rawMonth = match.group(2)!.toLowerCase();
        String timePart = match.group(3)!;

        int month = 3;
        if (rawMonth.contains('mart')) {
          month = 3;
        } else if (rawMonth.contains('ubat') || rawMonth.contains('şubat')) {
          month = 2;
        } else if (rawMonth.contains('ocak')) {
          month = 1;
        }

        List<String> tParts = timePart.split(':');
        DateTime currentMatchDate = DateTime(2026, month, day, int.parse(tParts[0]), int.parse(tParts[1]));

        double amount = double.tryParse(match.group(4) ?? "0") ?? 0;
        String unit = match.group(5) ?? "Kb";

        if (unit != "Sn") {
          if (minDate == null || currentMatchDate.isBefore(minDate)) minDate = currentMatchDate;
          if (maxDate == null || currentMatchDate.isAfter(maxDate)) maxDate = currentMatchDate;

          if (unit == "Kb") {
            totalPdfMb += (amount / 1024);
          } else if (unit == "Gb") {
            totalPdfMb += (amount * 1024);
          } else {
            totalPdfMb += amount;
          }
        }
      } catch (e) { continue; }
    }

    if (totalPdfMb > 0 && minDate != null) {
      _calculateDrift(totalPdfMb, minDate, maxDate ?? minDate);
    } else {
      setState(() => _status = "Eşleşme bulunamadı.");
    }
  }

  Future<void> _calculateDrift(double pdfUsage, DateTime start, DateTime end) async {
    try {
      final List<Map<String, dynamic>> allRows = await DatabaseHelper.instance.queryAllRows();
      double deviceTotalMb = 0;

      for (var row in allRows) {
        DateTime rowDate = DateTime.parse(row['date']);
        if ((rowDate.isAfter(start) || _isSameDay(rowDate, start)) &&
            (rowDate.isBefore(end) || _isSameDay(rowDate, end))) {
          deviceTotalMb += (row['mobile_mb'] as double? ?? 0.0);
        }
      }

      double drift = (pdfUsage > 0) ? ((deviceTotalMb - pdfUsage).abs() / pdfUsage) * 100 : 0;

      Color dColor = Colors.greenAccent.shade700;
      if (drift > 50) {
        dColor = Colors.redAccent;
      } else if (drift > 20) {
        dColor = Colors.orangeAccent;
      }

      final List<String> monthNames = ["", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];

      setState(() {
        _driftPercent = drift;
        _driftColor = dColor;
        _resultData = {
          'range': "${start.day} ${monthNames[start.month]} - ${end.day} ${monthNames[end.month]} 2026",
          'operator': _formatUsage(pdfUsage),
          'device': _formatUsage(deviceTotalMb),
        };
        _status = "Cihaz verisi operatör verisiyle karşılaştırıldı";
      });
    } catch (e) {
      setState(() => _status = "Hata: $e");
    }
  }

  static String _parsePdfInBackground(Uint8List bytes) {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final String text = PdfTextExtractor(document).extractText();
    document.dispose();
    return text;
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), // Diğer sekmelerle uyumlu hafif ton
      appBar: AppBar(title: const Text('Veri Doğrulama')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // İkon Alanı - Gradyanlı Tasarım
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade400, Colors.purple.shade400],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
                ],
              ),
              child: const Icon(Icons.fact_check_rounded, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 30),

            // Dinamik Yazı Alanı
            Text(
              _status,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo.shade900
              ),
            ),
            const SizedBox(height: 30),

            // Dinamik Sonuç Alanı
            if (_resultData != null) ...[
              // Sapma Dairesi
              Container(
                width: 140, height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _driftColor, width: 6),
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: _driftColor.withOpacity(0.1), blurRadius: 15)],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                        "%${_driftPercent.toStringAsFixed(1)}",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _driftColor)
                    ),
                    Text("Sapma", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Bilgi Kartları (Aynı Hizada Kart Yapısı)
              _buildModernRow(Icons.calendar_month_rounded, "Analiz Aralığı:", _resultData!['range'], Colors.blue),
              _buildModernRow(Icons.sensors_rounded, "Operatör Verisi:", _resultData!['operator'], Colors.deepPurple),
              _buildModernRow(Icons.phonelink_ring_rounded, "Cihaz Verisi:", _resultData!['device'], Colors.purple),
            ],

            const SizedBox(height: 40),

            // Analiz Butonu - Gradyanlı
            if (_isProcessing)
              const CircularProgressIndicator(color: Colors.indigo)
            else
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: [Colors.blue.shade600, Colors.indigo.shade700]),
                  boxShadow: [
                    BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _pickAndProcessPDF,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text("PDF ANALİZ ET", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Modern Bilgi Satırı Widget'ı (Kart Görünümlü)
  Widget _buildModernRow(IconData icon, String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- SEKME 4: TARİFE ÖNERİSİ (AI) ---
class SuggestionPage extends StatelessWidget {
  const SuggestionPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tarife Önerisi')),
      body: const Center(child: Text('AI Destekli Öneriler Çok Yakında!')),
    );
  }
}