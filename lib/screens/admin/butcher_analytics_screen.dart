import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/status_chip.dart';
import '../../services/butcher_service.dart';
import '../../models/butcher_models.dart';
import '../../services/user_provider.dart';
import '../../services/menu_service.dart';
import '../../widgets/role_pop_scope.dart';

class ButcherAnalyticsScreen extends ConsumerStatefulWidget {
  const ButcherAnalyticsScreen({super.key});

  @override
  ConsumerState<ButcherAnalyticsScreen> createState() => _ButcherAnalyticsScreenState();
}

class _ButcherAnalyticsScreenState extends ConsumerState<ButcherAnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    final isDesktop = ResponsiveLayout.isDesktop(context);
    final logsAsync = ref.watch(slaughterLogsProvider);
    const currentRoute = '/admin/butcher';
    final menuItems = ref.watch(menuItemsProvider);

    return RolePopScope(
      currentRoute: currentRoute,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const MainAppBar(title: 'Butcher & Slaughter Analytics'),
        drawer: isDesktop ? null : Drawer(
          child: AppSidebar(
            userId: user.id,
            userName: user.name,
            userRole: user.activePrimaryRole.name.toUpperCase(),
            currentRoute: currentRoute,
            items: menuItems,
            onTap: (route) => MenuService.navigate(context, route, currentRoute),
          ),
        ),
        body: Row(
          children: [
            if (isDesktop)
              AppSidebar(
                userId: user.id,
                userName: user.name,
                userRole: user.activePrimaryRole.name.toUpperCase(),
                currentRoute: currentRoute,
                items: menuItems,
                onTap: (route) => MenuService.navigate(context, route, currentRoute),
              ),
            Expanded(
              child: logsAsync.when(
                data: (logs) => _buildContent(context, logs),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading analytics: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<SlaughterLog> logs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryKPIs(logs),
          const SizedBox(height: AppSpacing.xl),
          _buildDailySlaughterChart(logs),
          const SizedBox(height: AppSpacing.xl),
          _buildSlaughterTable(logs),
        ],
      ),
    );
  }

  Widget _buildSummaryKPIs(List<SlaughterLog> logs) {
    final totalAnimals = logs.length;
    final totalWeight = logs.fold(0.0, (sum, l) => sum + l.liveWeight);
    final completedSlaughters = logs.where((l) => 
      l.status == SlaughterStatus.completed || 
      l.status == SlaughterStatus.processed
    ).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return GridView.count(
          crossAxisCount: isMobile ? 2 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.m,
          mainAxisSpacing: AppSpacing.m,
          childAspectRatio: isMobile ? 1.4 : 2.5,
          children: [
            _kpiCard('Total Intakes', '$totalAnimals', Icons.pets, Colors.blue),
            _kpiCard('Total Weight', '${totalWeight.toStringAsFixed(1)} kg', Icons.scale, Colors.orange),
            _kpiCard('Slaughters Done', '$completedSlaughters', Icons.done_all, Colors.green),
          ],
        );
      },
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySlaughterChart(List<SlaughterLog> logs) {
    // Group logs by day for the last 7 days
    final now = DateTime.now();
    final last7Days = List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      return DateTime(date.year, date.month, date.day);
    });

    final dailyCounts = last7Days.map((day) {
      return logs.where((l) {
        final logDate = l.slaughterTime ?? DateTime.now(); // Fallback if not slaughtered yet
        return logDate.year == day.year && logDate.month == day.month && logDate.day == day.day;
      }).length;
    }).toList();

    final maxCount = dailyCounts.isEmpty ? 10.0 : (dailyCounts.reduce((a, b) => a > b ? a : b).toDouble() + 2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Slaughter Operations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Tracking volume over the last 7 days', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxCount,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${dailyCounts[groupIndex]} Animals',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= last7Days.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('E').format(last7Days[index]),
                              style: const TextStyle(fontSize: 10, color: AppColors.textLight),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(dailyCounts.length, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: dailyCounts[index].toDouble(),
                          color: AppColors.primaryMaroon,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlaughterTable(List<SlaughterLog> logs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('All Slaughter Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.m),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 800),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Batch ID')),
                    DataColumn(label: Text('Farm Tag')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Purchase Cost')),
                    DataColumn(label: Text('Selling Price')),
                    DataColumn(label: Text('Est. Profit')),
                    DataColumn(label: Text('Time')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: logs.map((log) {
                    final profit = log.estimatedProfit;
                    return DataRow(cells: [
                      DataCell(Text(log.id.substring(log.id.length - 8).toUpperCase(), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      DataCell(Text(log.manualFarmTag ?? 'N/A', style: const TextStyle(fontSize: 11, color: Colors.blue))),
                      DataCell(Text(log.type.displayName, style: const TextStyle(fontSize: 11))),
                      DataCell(Text(log.farmPrice != null ? '₵${log.farmPrice!.toStringAsFixed(2)}' : '₵0.00', 
                        style: const TextStyle(fontSize: 11))),
                      DataCell(Text('₵${log.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11))),
                      DataCell(Text('₵${profit.toStringAsFixed(2)}', 
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: profit >= 0 ? Colors.green : Colors.red))),
                      DataCell(Text(
                        log.slaughterTime != null 
                          ? DateFormat('MMM dd, HH:mm').format(log.slaughterTime!) 
                          : 'Pending',
                        style: const TextStyle(fontSize: 11),
                      )),
                      DataCell(StatusChip(
                        label: log.status.name.toUpperCase(), 
                        color: (log.status == SlaughterStatus.completed || log.status == SlaughterStatus.processed) ? Colors.green : Colors.orange,
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
