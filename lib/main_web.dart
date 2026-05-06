import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

void main() {
  runApp(const DataVerifyWebApp());
}

class DataVerifyWebApp extends StatelessWidget {
  const DataVerifyWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verifyte Web',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
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
  final List<int> _history = [];

  final List<Widget> _pages = const [
    DashboardPage(),
    StatisticsPage(),
    VerifyPage(),
    SuggestionPage(),
  ];

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _history.add(_currentIndex);
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _history.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _history.isNotEmpty) {
          setState(() => _currentIndex = _history.removeLast());
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF5F3FF), Color(0xFFE4DCFF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: IndexedStack(index: _currentIndex, children: _pages),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTap,
          selectedItemColor: Colors.indigo,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Özet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_graph_rounded),
              label: 'İstatistik',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fact_check_rounded),
              label: 'Doğrulama',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tips_and_updates_rounded),
              label: 'Öneri',
            ),
          ],
        ),
      ),
    );
  }
}

// --- WEB INFO CARD ---
class WebInfoWarning extends StatelessWidget {
  final String message;

  const WebInfoWarning({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6D4C00),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- SEKME 1: DASHBOARD WEB ---
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final Map<dynamic, dynamic> _allUsageSummary = {
    '1h_mobile': 0.0,
    '1h_wifi': 0.0,
    '1d_mobile': 0.0,
    '1d_wifi': 0.0,
    '1w_mobile': 0.0,
    '1w_wifi': 0.0,
    '1m_mobile': 0.0,
    '1m_wifi': 0.0,
  };

  String _selectedPeriod = '1d';

  void _showMobileOnlyMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Bu özellik telefon verisine ihtiyaç duyar. Gerçek ölçüm için Android uygulama versiyonunu kullanın.',
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    _showMobileOnlyMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Kullanım Detayları'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _showMobileOnlyMessage,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const WebInfoWarning(
                message:
                    'Web sürümü telefonun gerçek mobil veri kullanımını okuyamaz. Gerçek ölçüm ve uygulama bazlı tüketim için Android uygulama versiyonunu kullanın.',
              ),
              _buildSummaryGrid(),
              _buildComparisonCard(),
              _buildPeriodSelector(),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    Icon(Icons.list_alt_rounded,
                        color: Colors.indigo, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Uygulama Bazlı Tüketim',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _mobileOnlyCard(
                  icon: Icons.phone_android_rounded,
                  title: 'Uygulama listesi webde gösterilemez',
                  description:
                      'Tarayıcılar telefondaki uygulama bazlı mobil veri kullanımına erişemez.',
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileOnlyCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: Colors.indigo),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
      ),
    );
  }

  Widget _buildSummaryGrid() {
    final cards = [
      {
        'title': 'Son 1 Saat',
        'value': "${_allUsageSummary['1h_mobile']?.toStringAsFixed(1)} MB",
        'icon': Icons.schedule_rounded,
        'colors': [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
      },
      {
        'title': 'Bugün',
        'value': "${_allUsageSummary['1d_mobile']?.toStringAsFixed(1)} MB",
        'icon': Icons.today_rounded,
        'colors': [const Color(0xFF283593), const Color(0xFF5C6BC0)],
      },
      {
        'title': 'Bu Hafta',
        'value': "${_allUsageSummary['1w_mobile']?.toStringAsFixed(1)} MB",
        'icon': Icons.date_range_rounded,
        'colors': [const Color(0xFF4527A0), const Color(0xFF9575CD)],
      },
      {
        'title': 'Bu Ay',
        'value': "${_allUsageSummary['1m_mobile']?.toStringAsFixed(1)} MB",
        'icon': Icons.calendar_month_rounded,
        'colors': [const Color(0xFF6A1B9A), const Color(0xFFBA68C8)],
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 2,
        childAspectRatio: 2.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        physics: const NeverScrollableScrollPhysics(),
        children: cards
            .map(
              (c) => _summaryCard(
                c['title'] as String,
                c['value'] as String,
                c['icon'] as IconData,
                c['colors'] as List<Color>,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildComparisonCard() {
    final double mobile = _allUsageSummary['1m_mobile'] ?? 0.0;
    final double wifi = _allUsageSummary['1m_wifi'] ?? 0.0;
    final double total = mobile + wifi;
    final double savingRate = total > 0 ? (wifi / total) : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Aylık Veri Dengesi",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
              _indicatorLabel(
                  "Wi-Fi", "${wifi.toStringAsFixed(1)} MB", Colors.green),
              _indicatorLabel("Mobil", "${mobile.toStringAsFixed(1)} MB",
                  Colors.orangeAccent),
            ],
          ),
          const Divider(height: 30),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Text('⚠️', style: TextStyle(fontSize: 14)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Bu değerler web sürümünde ölçülemez. Gerçek Wi-Fi / mobil veri dengesi için Android uygulamayı kullanın.",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _indicatorLabel(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text("$label: ",
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _summaryCard(
      String title, String value, IconData icon, List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors[0].withAlpha(80),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  )),
              Icon(icon, color: Colors.white38, size: 15),
            ],
          ),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = {
      '1h': '1 Saat',
      '1d': '1 Gün',
      '1w': '1 Hafta',
      '1m': '1 Ay'
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: periods.entries
          .map(
            (e) => ChoiceChip(
              label: Text(e.value),
              selected: _selectedPeriod == e.key,
              onSelected: (val) {
                if (val) {
                  setState(() => _selectedPeriod = e.key);
                  _showMobileOnlyMessage();
                }
              },
              selectedColor: Colors.indigo.shade100,
              labelStyle: TextStyle(
                color:
                    _selectedPeriod == e.key ? Colors.indigo : Colors.black87,
              ),
            ),
          )
          .toList(),
    );
  }
}

// --- SEKME 2: İSTATİSTİK WEB ---
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  List<Map<String, dynamic>> _monthlyData = [];
  bool _isLoading = false;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _fetchMonthlyData();
  }

  String _formatFullDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final months = [
        "",
        "Ocak",
        "Şubat",
        "Mart",
        "Nisan",
        "Mayıs",
        "Haziran",
        "Temmuz",
        "Ağustos",
        "Eylül",
        "Ekim",
        "Kasım",
        "Aralık"
      ];
      return "${dt.day} ${months[dt.month]} ${dt.year}";
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _fetchMonthlyData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final demo = List.generate(90, (i) {
      final date = now.subtract(Duration(days: 89 - i));
      return {
        'date':
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
        'usageMB': 0.0,
      };
    });

    if (mounted) {
      setState(() {
        _monthlyData = demo;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportCSV() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'CSV dışa aktarma ve kayıtlı telefon verisi için Android uygulama versiyonunu kullanın.',
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    await _fetchMonthlyData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Web sürümünde gerçek telefon kullanım geçmişi okunamaz.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('90 Günlük Analiz'),
        actions: [
          IconButton(
              icon: const Icon(Icons.file_download_outlined),
              onPressed: _exportCSV),
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _isLoading ? null : _refresh),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const WebInfoWarning(
                      message:
                          'İstatistik sayfası telefonun geçmiş kullanım kayıtlarına ihtiyaç duyar. Web sürümü bu verilere erişemediği için grafik demo/boş değerlerle gösterilir.',
                    ),
                    const SizedBox(height: 18),
                    _buildChartArea(),
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Divider(),
                    ),
                    _buildDailyList(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildChartArea() {
    if (_monthlyData.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(child: Text("Veri yok")),
      );
    }

    final maxVal =
        _monthlyData.map((e) => e['usageMB'] as double).reduce(math.max);
    final safeMax = maxVal <= 0 ? 1.0 : maxVal;
    final double gridInterval =
        safeMax > 0 ? (safeMax / 4).ceilToDouble() : 500.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade100.withOpacity(0.6),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 24, 16, 12),
        child: SizedBox(
          height: 280,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: safeMax * 1.25,
              barTouchData: BarTouchData(
                enabled: true,
                touchCallback: (event, response) {
                  setState(() {
                    _touchedIndex = response?.spot != null
                        ? response!.spot!.touchedBarGroupIndex
                        : -1;
                  });
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) =>
                      Colors.indigo.shade900.withOpacity(0.92),
                  tooltipRoundedRadius: 10,
                  tooltipPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  getTooltipItem: (group, _, rod, __) {
                    final dayData = _monthlyData[group.x];
                    final date = _formatFullDate(dayData['date'] as String);
                    final mb = (dayData['usageMB'] as double).toStringAsFixed(2);
                    return BarTooltipItem(
                      '$date\n',
                      const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                      children: [
                        TextSpan(
                          text: '$mb MB',
                          style: const TextStyle(
                            color: Colors.lightBlueAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: gridInterval,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: Colors.grey.shade200, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, m) {
                      if (v == 0) return const SizedBox();
                      final label =
                          v >= 1000 ? "${(v / 1000).toStringAsFixed(1)}G" : "${v.toInt()}";
                      return SideTitleWidget(
                        meta: m,
                        child: Text(label,
                            style: const TextStyle(
                                fontSize: 9, color: Colors.grey)),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      final total = _monthlyData.length;
                      if (total == 0) return const SizedBox();
                      final points = [
                        0,
                        (total / 4).floor(),
                        (total / 2).floor(),
                        (total * 3 / 4).floor(),
                        total - 1
                      ];
                      if (index >= 0 &&
                          index < total &&
                          points.contains(index)) {
                        final dt =
                            DateTime.parse(_monthlyData[index]['date'] as String);
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            "${dt.day}/${dt.month}",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade400,
                            ),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: _monthlyData.asMap().entries.map((e) {
                final isTouched = e.key == _touchedIndex;
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value['usageMB'] as double,
                      gradient: LinearGradient(
                        colors: isTouched
                            ? [Colors.amber.shade300, Colors.orange.shade500]
                            : [
                                Colors.blue.shade300,
                                Colors.deepPurple.shade400
                              ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: isTouched ? 5 : 3,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                );
              }).toList(),
            ),
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
          leading:
              Icon(Icons.calendar_today, size: 18, color: Colors.indigo.shade300),
          title: Text(
            _formatFullDate(dayData['date'] as String),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          trailing: Text(
            "${(dayData['usageMB'] as double).toStringAsFixed(2)} MB",
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.indigo),
          ),
        );
      },
    );
  }
}

// --- SEKME 3: DOĞRULAMA WEB ---
class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  String _status = "Operatör PDF dökümanını yükleyin.";
  bool _isProcessing = false;
  Map<String, dynamic>? _resultData;
  Color _resultColor = Colors.deepPurple;
  String? _selectedOperator;
  Map<String, double> _dailyOperatorMb = {};

  static const Map<String, int> _monthMap = {
    'ocak': 1,
    'subat': 2,
    'ubat': 2,
    'mart': 3,
    'nisan': 4,
    'mayis': 5,
    'haziran': 6,
    'temmuz': 7,
    'agustos': 8,
    'eylul': 9,
    'ekim': 10,
    'kasim': 11,
    'aralik': 12,
  };

  String _formatUsage(double totalMb) {
    final gb = totalMb ~/ 1024;
    final mb = (totalMb % 1024).toInt();
    final kb = ((totalMb - totalMb.toInt()) * 1024).toInt();

    final parts = <String>[];
    if (gb > 0) parts.add("$gb GB");
    if (mb > 0) parts.add("$mb MB");
    if (kb > 0) parts.add("$kb KB");

    return parts.isEmpty ? "0 KB" : parts.join(", ");
  }

  Future<String?> _showOperatorDialog() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Operatör Seçin',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Turkcell', 'Türk Telekom', 'Vodafone']
              .map(
                (op) => ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.sim_card_outlined),
                  title: Text(op),
                  onTap: () => Navigator.pop(ctx, op),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _pickAndProcessPDF() async {
    final operator = await _showOperatorDialog();
    if (operator == null || !mounted) return;

    setState(() {
      _selectedOperator = operator;
      _resultData = null;
      _dailyOperatorMb = {};
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _isProcessing = true;
          _status = "PDF analiz ediliyor...";
        });

        final Uint8List bytes = result.files.single.bytes!;
        final String extractedText = await compute(_parsePdfInBackground, bytes);

        if (!mounted) return;

        if (extractedText.trim().isNotEmpty) {
          if (_selectedOperator == 'Türk Telekom') {
            _analyzeTurkTelekom(extractedText);
          } else if (_selectedOperator == 'Vodafone') {
            _analyzeVodafone(extractedText);
          } else {
            _analyzeOperatorData(extractedText);
          }
        } else {
          setState(() => _status = "Hata: PDF'ten metin ayıklanamadı.");
        }
      }
    } catch (e) {
      setState(() => _status = "Hata: PDF işlenemedi ($e)");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _normalizeMonth(String raw) {
    return raw
        .toLowerCase()
        .replaceAll('ş', 's')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ğ', 'g')
        .replaceAll('ç', 'c')
        .replaceAll('İ', 'i')
        .replaceAll('Ş', 's');
  }

  int? _parseMonth(String rawMonth) {
    final normalized = _normalizeMonth(rawMonth);
    for (final entry in _monthMap.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return null;
  }

  void _analyzeVodafone(String rawText) {
    final yearMatch = RegExp(r'\b(20[2-9]\d)\b').firstMatch(rawText);
    final int baseYear =
        yearMatch != null ? int.parse(yearMatch.group(1)!) : DateTime.now().year;

    const vodafoneMonthMap = <String, int>{
      'oca': 1,
      'sub': 2,
      'ub': 2,
      'mar': 3,
      'nis': 4,
      'may': 5,
      'haz': 6,
      'tem': 7,
      'agu': 8,
      'au': 8,
      'eyl': 9,
      'eki': 10,
      'kas': 11,
      'ara': 12,
    };

    final dataRegExp = RegExp(
      r'(\d{2})([A-Za-zĞğŞşİıÇçÖöÜü]{2,3})(\d{2}:\d{2})\s*Internet\s*([\d.,]+)\s*(KB|Kb|MB|Mb|GB|Gb)',
      dotAll: true,
    );

    final entries = <Map<String, dynamic>>[];

    for (final match in dataRegExp.allMatches(rawText)) {
      try {
        final day = int.parse(match.group(1)!);
        final normMonth = _normalizeMonth(match.group(2)!);

        int? month;
        for (final e in vodafoneMonthMap.entries) {
          if (normMonth == e.key) {
            month = e.value;
            break;
          }
        }
        if (month == null) continue;

        final timePart = match.group(3)!;
        final value =
            double.tryParse((match.group(4) ?? '0').replaceAll(',', '.')) ?? 0;
        if (value == 0) continue;

        final unit = (match.group(5) ?? 'KB').toLowerCase();
        final tParts = timePart.split(':');
        final dt = DateTime(
          baseYear,
          month,
          day,
          int.parse(tParts[0]),
          int.parse(tParts[1]),
        );

        final mb = unit == 'kb'
            ? value / 1024.0
            : unit == 'gb'
                ? value * 1024.0
                : value;

        entries.add({'date': dt, 'mb': mb});
      } catch (_) {
        continue;
      }
    }

    if (entries.isEmpty) {
      setState(() => _status = "Eşleşme bulunamadı. PDF formatını kontrol edin.");
      return;
    }

    final seenMonths = entries.map((e) => (e['date'] as DateTime).month).toSet();
    if (seenMonths.contains(12) && seenMonths.contains(1)) {
      for (int i = 0; i < entries.length; i++) {
        final dt = entries[i]['date'] as DateTime;
        if (dt.month <= 3) {
          entries[i] = {
            'date': DateTime(dt.year + 1, dt.month, dt.day, dt.hour, dt.minute),
            'mb': entries[i]['mb'],
          };
        }
      }
    }

    _finalizeOperatorEntries(entries);
  }

  void _analyzeTurkTelekom(String rawText) {
    final dataRegExp = RegExp(
      r'GPRS\s+internet\.04\s+(\d{2})/(\d{2})/(\d{4})\s+(\d{2}:\d{2}):\d{2}\s+(\d+)',
    );

    final entries = <Map<String, dynamic>>[];

    for (final match in dataRegExp.allMatches(rawText)) {
      try {
        final day = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final year = int.parse(match.group(3)!);
        final timePart = match.group(4)!;
        final bytes = double.tryParse(match.group(5) ?? '0') ?? 0;

        final tParts = timePart.split(':');
        final dt =
            DateTime(year, month, day, int.parse(tParts[0]), int.parse(tParts[1]));
        final mb = bytes / 1048576.0;

        entries.add({'date': dt, 'mb': mb});
      } catch (_) {
        continue;
      }
    }

    if (entries.isEmpty) {
      setState(() => _status = "Eşleşme bulunamadı. PDF formatını kontrol edin.");
      return;
    }

    _finalizeOperatorEntries(entries);
  }

  void _analyzeOperatorData(String rawText) {
    final dataRegExp = RegExp(
      r"(\d{2})\s+([a-zA-ZşŞüÜçÇöÖıİğĞ]+),?\s+(\d{2}:\d{2}).*?([\d.,]+)\s+(KB|Kb|MB|Mb|GB|Gb|Sn)",
      dotAll: true,
    );

    final entries = <Map<String, dynamic>>[];

    for (final match in dataRegExp.allMatches(rawText)) {
      try {
        final day = int.parse(match.group(1)!);
        final month = _parseMonth(match.group(2)!);
        if (month == null) continue;

        final timePart = match.group(3)!;
        final amount =
            double.tryParse((match.group(4) ?? '0').replaceAll(',', '.')) ?? 0;
        final unit = (match.group(5) ?? 'KB').toLowerCase();

        if (unit == 'sn') continue;

        final tParts = timePart.split(':');
        final dt =
            DateTime(DateTime.now().year, month, day, int.parse(tParts[0]), int.parse(tParts[1]));

        final mb = unit == 'kb'
            ? amount / 1024
            : unit == 'gb'
                ? amount * 1024
                : amount;

        entries.add({'date': dt, 'mb': mb});
      } catch (_) {
        continue;
      }
    }

    if (entries.isEmpty) {
      setState(() => _status = "Eşleşme bulunamadı. PDF formatını kontrol edin.");
      return;
    }

    _finalizeOperatorEntries(entries);
  }

  void _finalizeOperatorEntries(List<Map<String, dynamic>> entries) {
    final allDates = entries.map((e) => e['date'] as DateTime).toList();
    final periodStart = allDates.reduce((a, b) => a.isBefore(b) ? a : b);
    final periodEnd = allDates.reduce((a, b) => a.isAfter(b) ? a : b);

    final dailyOperatorMb = <String, double>{};

    for (final entry in entries) {
      final dt = entry['date'] as DateTime;
      final key =
          "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      dailyOperatorMb[key] =
          (dailyOperatorMb[key] ?? 0.0) + (entry['mb'] as double);
    }

    final totalPdfMb = dailyOperatorMb.values.fold(0.0, (s, v) => s + v);

    if (totalPdfMb > 0) {
      _calculateWebOperatorResult(
          dailyOperatorMb, totalPdfMb, periodStart, periodEnd);
    } else {
      setState(() => _status = "Eşleşme bulunamadı. PDF formatını kontrol edin.");
    }
  }

  Future<void> _calculateWebOperatorResult(
    Map<String, double> dailyOperatorMb,
    double totalPdfMb,
    DateTime start,
    DateTime end,
  ) async {
    final monthNames = [
      "",
      "Ocak",
      "Şubat",
      "Mart",
      "Nisan",
      "Mayıs",
      "Haziran",
      "Temmuz",
      "Ağustos",
      "Eylül",
      "Ekim",
      "Kasım",
      "Aralık"
    ];

    final rangeStr = start.year == end.year
        ? "${start.day} ${monthNames[start.month]} - ${end.day} ${monthNames[end.month]} ${end.year}"
        : "${start.day} ${monthNames[start.month]} ${start.year} - ${end.day} ${monthNames[end.month]} ${end.year}";

    setState(() {
      _resultColor = Colors.deepPurple;
      _dailyOperatorMb = dailyOperatorMb;
      _resultData = {
        'range': rangeStr,
        'operator': _formatUsage(totalPdfMb),
        'device': 'Web sürümünde ölçülemez',
        'coverage': '${dailyOperatorMb.length} gün',
        'operatorName': _selectedOperator ?? 'Operatör',
      };
      _status = "Operatör PDF verisi analiz edildi";
    });
  }

  static String _parsePdfInBackground(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    document.dispose();
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar:
          AppBar(title: const Text('Doğrulama'), backgroundColor: Colors.transparent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KARŞILAŞTIRMA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.deepPurple.shade400,
                  letterSpacing: 1.8,
                )),
            const SizedBox(height: 10),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 32,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    height: 1.1),
                children: [
                  const TextSpan(text: 'Faturanı '),
                  TextSpan(
                    text: 'doğrula.',
                    style: TextStyle(
                      color: Colors.deepPurple.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Operatörünün PDF dökümanını yükle. Web sürümü telefon verisini ölçemediği için yalnızca operatör verilerini analiz eder.',
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade600, height: 1.55),
            ),
            const SizedBox(height: 14),
            const WebInfoWarning(
              message:
                  'Operatör - cihaz karşılaştırması için telefondan ölçülen kullanım verisi gerekir. Web sürümünde sadece PDF ile yüklenen operatör verisi gösterilir.',
            ),
            const SizedBox(height: 20),
            if (_resultData != null) _buildResultSection() else _buildUploadArea(),
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                    child: CircularProgressIndicator(color: Colors.deepPurple)),
              ),
            if (_resultData == null) ...[
              const SizedBox(height: 40),
              _buildHowItWorks(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    return GestureDetector(
      onTap: _pickAndProcessPDF,
      child: CustomPaint(
        painter:
            _DashedBorderPainter(color: Colors.deepPurple.shade200, radius: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF3EEFF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.shade300, Colors.purple.shade500],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.description_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 14),
              const Text('Dosya seç ve analiz et',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Maksimum 10 MB · sadece operatör faturası',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHowItWorks() {
    final steps = [
      {
        'num': '01',
        'title': 'PDF yüklenir',
        'desc': 'Tarayıcıda işlenir; dosya sunucuya gönderilmez.'
      },
      {
        'num': '02',
        'title': 'Sayılar çıkarılır',
        'desc': 'Operatörün bildirdiği MB ve GB değerleri ayıklanır.'
      },
      {
        'num': '03',
        'title': 'Operatör verisi gösterilir',
        'desc': 'Web sürümünde telefon verisiyle karşılaştırma yapılmaz.'
      },
      {
        'num': '04',
        'title': 'Mobil uygulama yönlendirmesi',
        'desc':
            'Gerçek cihaz karşılaştırması için Android uygulama versiyonu kullanılır.'
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NASIL ÇALIŞIR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.deepPurple.shade400,
              letterSpacing: 1.8,
            )),
        const SizedBox(height: 20),
        ...steps.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['num']!,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.deepPurple.shade200,
                    )),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 3),
                      Text(s['title']!,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 3),
                      Text(s['desc']!,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultSection() {
    final sortedDays = _dailyOperatorMb.keys.toList()..sort();

    return Column(
      children: [
        Center(
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _resultColor, width: 6),
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: _resultColor.withAlpha(30), blurRadius: 15)
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf_rounded,
                    color: _resultColor, size: 34),
                const SizedBox(height: 8),
                Text("PDF",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _resultColor)),
                Text("Analiz", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        _buildModernRow(Icons.calendar_month_rounded, "Analiz Aralığı:",
            _resultData!['range'], Colors.blue),
        _buildModernRow(Icons.sensors_rounded,
            "${_resultData!['operatorName']} Verisi:", _resultData!['operator'], Colors.deepPurple),
        _buildModernRow(Icons.phonelink_ring_rounded, "Cihaz Verisi:",
            _resultData!['device'], Colors.purple),
        _buildModernRow(Icons.date_range_rounded, "PDF Gün Sayısı:",
            _resultData!['coverage'], Colors.teal),
        const SizedBox(height: 14),
        if (sortedDays.isNotEmpty)
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              title: const Text('Günlük Operatör Verileri',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              children: sortedDays
                  .map(
                    (day) => ListTile(
                      dense: true,
                      leading:
                          const Icon(Icons.calendar_today_rounded, size: 17),
                      title: Text(day),
                      trailing: Text(
                        _formatUsage(_dailyOperatorMb[day] ?? 0),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _pickAndProcessPDF,
          icon: Icon(Icons.refresh_rounded,
              size: 16, color: Colors.deepPurple.shade400),
          label: Text('Farklı bir PDF analiz et',
              style: TextStyle(color: Colors.deepPurple.shade400, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildModernRow(IconData icon, String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration:
                BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    const dashLen = 6.0;
    const gapLen = 5.0;

    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dashLen), paint);
        d += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

// --- SEKME 4: TAHMİN WEB ---
class SuggestionPage extends StatelessWidget {
  const SuggestionPage({super.key});

  void _showMobileOnly(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tahmin özelliği telefonun geçmiş kullanım verilerine ihtiyaç duyar. Android uygulama versiyonunu kullanın.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Tahmin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _showMobileOnly(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.data_usage_rounded,
                    size: 56, color: Colors.indigo),
              ),
              const SizedBox(height: 24),
              const Text('Paket Bilgisi Gerekli',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                'Pakedinizin ne zaman biteceğini tahmin edebilmemiz için telefonun geçmiş veri kullanımı gerekir. Web sürümü telefon verisini okuyamadığı için bu özellik Android uygulama versiyonunda kullanılabilir.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.phone_android_rounded),
                label: const Text('Android Uygulama Gerekli'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _showMobileOnly(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
