import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/water_provider.dart';
import '../providers/step_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Geçmiş ve İstatistikler',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.water_drop), text: 'Su Takibi'),
            Tab(icon: Icon(Icons.directions_walk), text: 'Adımsayar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWaterHistoryTab(context),
          _buildStepHistoryTab(context),
        ],
      ),
    );
  }

  // --- 1. SEKMELİ SU GEÇMİŞİ ---
  Widget _buildWaterHistoryTab(BuildContext context) {
    final waterProvider = Provider.of<WaterProvider>(context);
    final theme = Theme.of(context);
    final stats = waterProvider.getPast7DaysStats();
    final historyList = waterProvider.getPast30DaysHistory();
    final int streak = waterProvider.streakCount;
    final int weeklyAvg = waterProvider.weeklyAverage;
    final int completedDays = waterProvider.weeklyCompletedDaysCount;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Row(
          children: [
            _buildSummaryCard(
              context,
              title: 'Başarı Serisi',
              value: '$streak Gün',
              icon: Icons.local_fire_department,
              iconColor: Colors.orange,
            ),
            const SizedBox(width: 8),
            _buildSummaryCard(
              context,
              title: 'Haftalık Ort.',
              value: '$weeklyAvg ml',
              icon: Icons.water_drop,
              iconColor: Colors.blue,
            ),
            const SizedBox(width: 8),
            _buildSummaryCard(
              context,
              title: 'Hedef Başarısı',
              value: '$completedDays / 7 Gün',
              icon: Icons.emoji_events,
              iconColor: Colors.amber,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Son 7 Günlük Su Tüketimi',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'Hedef: ${waterProvider.dailyTarget} ml',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 170,
                  child: BarChart(
                    _buildBarChartData(stats, waterProvider.dailyTarget),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Geçmiş Günlük Su Kayıtları',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        if (historyList.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Henüz geçmiş su kaydınız bulunmuyor.')),
          )
        else
          ...historyList.map((day) {
            final isToday = _isToday(day.date);
            final dateLabel = isToday
                ? 'Bugün'
                : DateFormat('d MMMM EEEE', 'tr_TR').format(day.date);
            final double ratio = day.target > 0 ? (day.totalAmount / day.target).clamp(0.0, 1.0) : 0.0;
            final int percent = (day.totalAmount / (day.target > 0 ? day.target : 1) * 100).toInt();

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              elevation: 0.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: day.isCompleted
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.blue.withValues(alpha: 0.15),
                              child: Icon(
                                day.isCompleted ? Icons.check_circle : Icons.water_drop,
                                size: 18,
                                color: day.isCompleted ? Colors.green : Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isToday ? Colors.blue : null,
                                  ),
                                ),
                                Text(
                                  '%$percent tamamlandı',
                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          '${day.totalAmount} / ${day.target} ml',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5,
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        color: day.isCompleted ? Colors.green : Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // --- 2. SEKMELİ ADIMSAYAR GEÇMİŞİ ---
  Widget _buildStepHistoryTab(BuildContext context) {
    final stepProvider = Provider.of<StepProvider>(context);
    final theme = Theme.of(context);
    final stats = stepProvider.getPast7DaysStepStats();
    final int totalWeekSteps = stats.fold(0, (sum, s) => sum + s.steps);
    final int weeklyAvgSteps = (totalWeekSteps / 7).round();
    final double totalWeekKm = totalWeekSteps * 0.00075;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Row(
          children: [
            _buildSummaryCard(
              context,
              title: 'Haftalık Toplam',
              value: '$totalWeekSteps',
              icon: Icons.directions_walk,
              iconColor: Colors.green,
            ),
            const SizedBox(width: 8),
            _buildSummaryCard(
              context,
              title: 'Günlük Ort.',
              value: '$weeklyAvgSteps',
              icon: Icons.speed,
              iconColor: Colors.teal,
            ),
            const SizedBox(width: 8),
            _buildSummaryCard(
              context,
              title: 'Toplam Mesafe',
              value: '${totalWeekKm.toStringAsFixed(1)} km',
              icon: Icons.map_outlined,
              iconColor: Colors.purple,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Son 7 Günlük Adım Grafiği',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'Hedef: ${stepProvider.stepTarget} adım',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 170,
                  child: BarChart(
                    _buildStepBarChartData(stats, stepProvider.stepTarget),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Geçmiş Günlük Adım Kayıtları',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 6),
        ...stats.reversed.map((day) {
          final isToday = _isToday(day.date);
          final dateLabel = isToday
              ? 'Bugün'
              : DateFormat('d MMMM EEEE', 'tr_TR').format(day.date);
          final double ratio = day.target > 0 ? (day.steps / day.target).clamp(0.0, 1.0) : 0.0;
          final int percent = (day.steps / (day.target > 0 ? day.target : 1) * 100).toInt();
          final double km = day.steps * 0.00075;
          final int kcal = (day.steps * 0.04).round();

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            elevation: 0.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: day.isCompleted
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.blueGrey.withValues(alpha: 0.15),
                            child: Icon(
                              day.isCompleted ? Icons.check_circle : Icons.directions_walk,
                              size: 18,
                              color: day.isCompleted ? Colors.green : Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isToday ? Colors.green[800] : null,
                                ),
                              ),
                              Text(
                                '${km.toStringAsFixed(2)} km  •  $kcal kcal',
                                style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${day.steps} adım',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            '%$percent',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: day.isCompleted ? Colors.green[700] : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 5,
                      backgroundColor: Colors.green.withValues(alpha: 0.1),
                      color: day.isCompleted ? const Color(0xFF22C55E) : const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(fontSize: 9, color: theme.colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  BarChartData _buildBarChartData(List<DayStat> stats, int target) {
    int maxVal = target > 0 ? target : 2000;
    for (var s in stats) {
      if (s.totalAmount > maxVal) maxVal = s.totalAmount;
    }
    // fl_chart çökmesini önlemek için: maxY mutlaka 0'dan büyük olmalı (minY = 0)
    final double maxY = maxVal > 0 ? (maxVal * 1.25).toDouble() : 1000.0;

    return BarChartData(
      maxY: maxY,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final int index = group.x.toInt();
            if (index < 0 || index >= stats.length) return null;
            final day = stats[index];
            final dayName = DateFormat('E', 'tr_TR').format(day.date);
            return BarTooltipItem(
              '$dayName\n${day.totalAmount} ml',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (value, meta) {
              if (value == 0) return const SizedBox.shrink();
              if (value.toInt() % 1000 == 0 || value.toInt() == target) {
                return Text(
                  '${(value / 1000).toStringAsFixed(1)}L',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= stats.length) return const SizedBox.shrink();
              final day = stats[index];
              final dayName = DateFormat('E', 'tr_TR').format(day.date);
              final isToday = _isToday(day.date);

              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  dayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? Colors.blue : Colors.grey,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1000,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey.withValues(alpha: 0.15),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: stats.asMap().entries.map((entry) {
        final index = entry.key;
        final day = entry.value;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: day.totalAmount.toDouble(),
              color: day.isCompleted ? Colors.green : Colors.blue,
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: target.toDouble(),
                color: Colors.grey.withValues(alpha: 0.1),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  BarChartData _buildStepBarChartData(List<StepDayStat> stats, int target) {
    int maxVal = target > 0 ? target : 8000;
    for (var s in stats) {
      if (s.steps > maxVal) maxVal = s.steps;
    }
    // fl_chart çökmesini önlemek için: maxY mutlaka 0'dan büyük olmalı (minY = 0)
    final double maxY = maxVal > 0 ? (maxVal * 1.25).toDouble() : 5000.0;

    return BarChartData(
      maxY: maxY,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final int index = group.x.toInt();
            if (index < 0 || index >= stats.length) return null;
            final day = stats[index];
            final dayName = DateFormat('E', 'tr_TR').format(day.date);
            return BarTooltipItem(
              '$dayName\n${day.steps} adım',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (value, meta) {
              if (value == 0) return const SizedBox.shrink();
              if (value.toInt() % 4000 == 0 || value.toInt() == target) {
                return Text(
                  '${(value / 1000).toStringAsFixed(0)}k',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= stats.length) return const SizedBox.shrink();
              final day = stats[index];
              final dayName = DateFormat('E', 'tr_TR').format(day.date);
              final isToday = _isToday(day.date);

              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  dayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? Colors.green[800] : Colors.grey,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 4000,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey.withValues(alpha: 0.15),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: stats.asMap().entries.map((entry) {
        final index = entry.key;
        final day = entry.value;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: day.steps.toDouble(),
              color: day.isCompleted ? const Color(0xFF22C55E) : const Color(0xFF16A34A),
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: target.toDouble(),
                color: Colors.grey.withValues(alpha: 0.1),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}
