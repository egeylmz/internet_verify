import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

import 'database_helper.dart';

void main() {
  runApp(const DataVerifyApp());
}

class DataVerifyApp extends StatelessWidget {
  const DataVerifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DataVerify Pro',
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
  final List<Widget> _pages = [const DashboardPage(), const StatisticsPage()];

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
    _fetchAllData();
  }

  // --- KRİTİK GÜNCELLEME: VERİ TABANI VE GEÇMİŞ VERİ AKTARIMI ---
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

      // 3. Her durumda bugünün verisini en güncel haliyle kaydet/güncelle
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
        title: const Text('DataVerify'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _isLoading ? null : _fetchAllData)],
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
          _summaryCard("Son 1 Saat", "${_allUsageSummary['1h_mobile']?.toStringAsFixed(1)} MB", Colors.blue),
          _summaryCard("Bugün", "${_allUsageSummary['1d_mobile']?.toStringAsFixed(1)} MB", Colors.indigo),
          _summaryCard("Bu Hafta", "${_allUsageSummary['1w_mobile']?.toStringAsFixed(1)} MB", Colors.deepPurple),
          _summaryCard("Bu Ay", "${_allUsageSummary['1m_mobile']?.toStringAsFixed(1)} MB", Colors.purple),
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
    return Card(
      elevation: 0, color: Colors.white, margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade50,
          child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
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
  static const platform = MethodChannel('com.example.internet_verify');
  List<dynamic> _monthlyData = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchMonthlyData();
  }

  Future<void> _fetchMonthlyData() async {
    setState(() => _isLoading = true);
    try {
      final List<dynamic> data = await platform.invokeMethod('getMonthlyDailyUsage');
      setState(() { _monthlyData = data.reversed.toList(); });
    } catch (e) { debugPrint("Hata: $e"); }
    finally { setState(() => _isLoading = false); }
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
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportCSV,
            tooltip: "Veriyi Dışa Aktar",
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _fetchMonthlyData,
          ),
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
      height: 250,
      child: Padding(
        padding: const EdgeInsets.only(right: 25, left: 10),
        child: BarChart(
          BarChartData(
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    int index = value.toInt();
                    if (index >= 0 && index < _monthlyData.length && index % 7 == 0) {
                      return SideTitleWidget(
                        meta: meta, space: 10,
                        child: Text(_monthlyData[index]['date'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      );
                    }
                    return const SizedBox();
                  },
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
                    color: Colors.indigoAccent, width: 8,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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
        final dayData = _monthlyData[_monthlyData.length - 1 - index];
        return ListTile(
          leading: const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.indigo),
          title: Text(index == 0 ? "Bugün" : dayData['date'], style: const TextStyle(fontWeight: FontWeight.w500)),
          trailing: Text("${(dayData['usageMB'] as double).toStringAsFixed(2)} MB", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        );
      },
    );
  }
}