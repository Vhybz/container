import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../models/sale_model.dart';
import '../services/sale_provider.dart';
import '../services/receipt_service.dart';
import '../services/sms_service.dart';
import '../widgets/status_badge.dart';

enum DateFilterMode { today, yesterday, custom }

class PosTransactionHistoryView extends ConsumerStatefulWidget {
  final VoidCallback? onSwitchToNewSale;
  final String? filterCategory;

  const PosTransactionHistoryView({
    super.key,
    this.onSwitchToNewSale,
    this.filterCategory,
  });

  @override
  ConsumerState<PosTransactionHistoryView> createState() => _PosTransactionHistoryViewState();
}

class _PosTransactionHistoryViewState extends ConsumerState<PosTransactionHistoryView> {
  DateFilterMode _dateFilterMode = DateFilterMode.today;
  DateTimeRange? _customDateRange;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Determines if an individual sale line item is allowed in the current sector/terminal
  bool _isItemAllowedForSector(SaleItem item) {
    if (widget.filterCategory == null || widget.filterCategory!.trim().isEmpty) {
      return true;
    }

    final catFilter = widget.filterCategory!.toUpperCase().trim();
    final cat = item.product.category.toUpperCase();
    final name = item.product.name.toUpperCase();

    if (catFilter == 'PHARMACY') {
      return item.product.requiresPrescription ||
          cat.contains('PHARM') || cat.contains('DRUG') || cat.contains('MED') ||
          cat.contains('ANTIBIOTIC') || cat.contains('SUPPLEMENT') || cat.contains('ANALGESIC') ||
          cat.contains('HEALTH') || cat.contains('CHEMIST') || cat.contains('OTC');
    } else if (catFilter == 'BARBER') {
      return cat.contains('BARBER') || cat.contains('HAIR') || cat.contains('BEARD') ||
          cat.contains('GROOM') || item.product.isService || cat.contains('SALON');
    } else if (catFilter == 'TECH') {
      return cat.contains('PHONE') || cat.contains('TECH') || cat.contains('REPAIR') ||
          cat.contains('ACCESS') || cat.contains('MOBILE') || name.contains('IPHONE') || name.contains('SAMSUNG');
    }

    return cat.contains(catFilter);
  }

  /// Converts a sale record so that it includes ONLY the items allowed for this sector
  SaleRecord _getSectorFilteredSale(SaleRecord sale) {
    if (widget.filterCategory == null || widget.filterCategory!.trim().isEmpty) {
      return sale;
    }

    final allowedItems = sale.items.where(_isItemAllowedForSector).toList();
    if (allowedItems.length == sale.items.length) {
      return sale;
    }

    final double allowedTotal = allowedItems.fold(0.0, (sum, i) => sum + i.total);
    final double allowedCost = allowedItems.fold(0.0, (sum, i) => sum + (i.quantity * i.product.costPrice));

    return sale.copyWith(
      items: allowedItems,
      totalAmount: allowedTotal,
      totalCost: allowedCost,
    );
  }

  List<SaleRecord> _getFilteredSales(List<SaleRecord> allSales) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (_dateFilterMode) {
      case DateFilterMode.today:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateFilterMode.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        break;
      case DateFilterMode.custom:
        if (_customDateRange != null) {
          startDate = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
          endDate = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
        } else {
          startDate = DateTime(now.year, now.month, now.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        }
        break;
    }

    final List<SaleRecord> result = [];

    for (var rawSale in allSales) {
      final inDate = rawSale.timestamp.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
          rawSale.timestamp.isBefore(endDate.add(const Duration(seconds: 1)));
      if (!inDate) continue;

      final sectorSale = _getSectorFilteredSale(rawSale);
      if (sectorSale.items.isEmpty) continue;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchId = sectorSale.id.toLowerCase().contains(q);
        final matchCustomer = (sectorSale.customerName ?? '').toLowerCase().contains(q);
        final matchCashier = sectorSale.cashierName.toLowerCase().contains(q);
        final matchProduct = sectorSale.items.any((i) => i.product.name.toLowerCase().contains(q));
        if (!matchId && !matchCustomer && !matchCashier && !matchProduct) {
          continue;
        }
      }

      result.add(sectorSale);
    }

    return result;
  }

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(now.year, now.month, now.day, 23, 59),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  scaffoldBackgroundColor: const Color(0xFF0F172A),
                  dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1E293B)),
                  colorScheme: const ColorScheme.dark(
                    primary: AppColors.accentBlue,
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E293B),
                    onSurface: Colors.white,
                  ),
                )
              : ThemeData.light().copyWith(
                  scaffoldBackgroundColor: const Color(0xFFF8FAFC),
                  dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.accentBlue,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF0F172A),
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _dateFilterMode = DateFilterMode.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final allSales = ref.watch(saleHistoryProvider);
    final filteredSales = _getFilteredSales(allSales);

    final activeSales = filteredSales.where((s) => s.isActive).toList();
    final double grossRevenue = activeSales.fold(0.0, (sum, s) => sum + s.totalAmount);
    final double totalCost = activeSales.fold(0.0, (sum, s) => sum + s.totalCost);
    final double netProfit = grossRevenue - totalCost;

    final String sectorTitle = widget.filterCategory != null && widget.filterCategory!.isNotEmpty
        ? '${widget.filterCategory!.toUpperCase()} POS LEDGER'
        : 'POS TRANSACTION LEDGER';

    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Column(
      children: [
        // Top Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border(bottom: BorderSide(color: borderCol)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.accentBlue, size: 20),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Text(
                  sectorTitle,
                  style: GoogleFonts.oswald(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.onSwitchToNewSale != null) ...[
                const SizedBox(width: AppSpacing.m),
                ElevatedButton.icon(
                  onPressed: widget.onSwitchToNewSale,
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: Text('NEW SALE', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                    elevation: 0,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Scrollable Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterControls(filteredSales, cardBg, borderCol, textPrimary, textSecondary),
                const SizedBox(height: AppSpacing.l),

                _buildKpiHeaderCards(theme, activeSales.length, grossRevenue, netProfit, cardBg, borderCol, textPrimary, textSecondary),
                const SizedBox(height: AppSpacing.l),

                _buildAnalyticsSection(theme, filteredSales, cardBg, borderCol, textPrimary, textSecondary),
                const SizedBox(height: AppSpacing.xl),

                // Section Header
                Row(
                  children: [
                    Text(
                      'TRANSACTION LOG',
                      style: GoogleFonts.oswald(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${filteredSales.length} Records',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentBlue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),

                if (filteredSales.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(AppRadius.l),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: AppSpacing.m),
                        Text(
                          'No sales records found for this period.',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try selecting a different date range or adjusting your search query.',
                          style: GoogleFonts.inter(color: textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredSales.length,
                    separatorBuilder: (context, i) => const SizedBox(height: AppSpacing.s),
                    itemBuilder: (context, index) {
                      final sale = filteredSales[index];
                      return _buildTransactionCard(theme, sale, cardBg, borderCol, textPrimary, textSecondary);
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterControls(
    List<SaleRecord> currentFilteredSales,
    Color cardBg,
    Color borderCol,
    Color textPrimary,
    Color textSecondary,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 800;

        final searchField = SizedBox(
          height: 42,
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            style: GoogleFonts.inter(color: textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search Invoice #, Customer, Cashier...',
              hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 13),
              prefixIcon: Icon(Icons.search, size: 18, color: textSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 16, color: textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
              fillColor: textSecondary.withValues(alpha: 0.06),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        );

        final dateSegments = Container(
          height: 42,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: textSecondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _filterSegmentBtn('Today', DateFilterMode.today, textPrimary, textSecondary),
              _filterSegmentBtn('Yesterday', DateFilterMode.yesterday, textPrimary, textSecondary),
              InkWell(
                onTap: _selectCustomDateRange,
                borderRadius: BorderRadius.circular(AppRadius.s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _dateFilterMode == DateFilterMode.custom ? AppColors.accentBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.date_range,
                        size: 14,
                        color: _dateFilterMode == DateFilterMode.custom ? Colors.white : textPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _dateFilterMode == DateFilterMode.custom && _customDateRange != null
                            ? '${DateFormat('MMM dd').format(_customDateRange!.start)} - ${DateFormat('MMM dd').format(_customDateRange!.end)}'
                            : 'Custom Range',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _dateFilterMode == DateFilterMode.custom ? Colors.white : textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        final printBtn = SizedBox(
          height: 42,
          child: ElevatedButton.icon(
            onPressed: currentFilteredSales.isEmpty
                ? null
                : () {
                    String rangeText = 'Today';
                    if (_dateFilterMode == DateFilterMode.yesterday) rangeText = 'Yesterday';
                    if (_dateFilterMode == DateFilterMode.custom && _customDateRange != null) {
                      rangeText = '${DateFormat('MMM dd, yyyy').format(_customDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_customDateRange!.end)}';
                    }
                    final String reportTitle = widget.filterCategory != null && widget.filterCategory!.isNotEmpty
                        ? '${widget.filterCategory!.toUpperCase()} Sales Ledger ($rangeText)'
                        : 'POS Sales Ledger ($rangeText)';
                    ReceiptService.printSalesReport(
                      currentFilteredSales,
                      title: reportTitle,
                    );
                  },
            icon: const Icon(Icons.print, size: 16),
            label: Text('PRINT REPORT', style: GoogleFonts.oswald(fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldSuccess,
              disabledBackgroundColor: textSecondary.withValues(alpha: 0.12),
              foregroundColor: Colors.white,
              disabledForegroundColor: textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
              elevation: 0,
            ),
          ),
        );

        if (isCompact) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AppRadius.l),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: AppSpacing.m),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      dateSegments,
                      const SizedBox(width: AppSpacing.m),
                      printBtn,
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(AppRadius.l),
            border: Border.all(color: borderCol),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: AppSpacing.m),
              dateSegments,
              const SizedBox(width: AppSpacing.m),
              printBtn,
            ],
          ),
        );
      },
    );
  }

  Widget _filterSegmentBtn(String label, DateFilterMode mode, Color textPrimary, Color textSecondary) {
    final isSelected = _dateFilterMode == mode;
    return InkWell(
      onTap: () => setState(() => _dateFilterMode = mode),
      borderRadius: BorderRadius.circular(AppRadius.s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.s),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildKpiHeaderCards(
    ThemeData theme,
    int totalCount,
    double revenue,
    double profit,
    Color cardBg,
    Color borderCol,
    Color textPrimary,
    Color textSecondary,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;

        final card1 = _kpiCard(
          title: 'SALES VOLUME',
          value: '$totalCount Orders',
          icon: Icons.receipt_long_rounded,
          color: AppColors.accentBlue,
          cardBg: cardBg,
          borderCol: borderCol,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );

        final card2 = _kpiCard(
          title: 'GROSS REVENUE',
          value: 'GHS ${revenue.toStringAsFixed(2)}',
          icon: Icons.payments_rounded,
          color: AppColors.emeraldSuccess,
          cardBg: cardBg,
          borderCol: borderCol,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );

        final card3 = _kpiCard(
          title: 'NET PROFIT',
          value: 'GHS ${profit.toStringAsFixed(2)}',
          icon: Icons.trending_up_rounded,
          color: Colors.amber.shade700,
          cardBg: cardBg,
          borderCol: borderCol,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );

        if (isCompact) {
          return Column(
            children: [
              card1,
              const SizedBox(height: AppSpacing.s),
              card2,
              const SizedBox(height: AppSpacing.s),
              card3,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: AppSpacing.m),
            Expanded(child: card2),
            const SizedBox(width: AppSpacing.m),
            Expanded(child: card3),
          ],
        );
      },
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color borderCol,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.oswald(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection(
    ThemeData theme,
    List<SaleRecord> sales,
    Color cardBg,
    Color borderCol,
    Color textPrimary,
    Color textSecondary,
  ) {
    final Map<int, double> hourlySales = {};
    for (int i = 8; i <= 20; i++) {
      hourlySales[i] = 0.0;
    }

    for (var s in sales.where((s) => s.isActive)) {
      final hour = s.timestamp.hour;
      if (hourlySales.containsKey(hour)) {
        hourlySales[hour] = hourlySales[hour]! + s.totalAmount;
      }
    }

    final Map<String, _ProductRank> productMap = {};
    for (var s in sales.where((s) => s.isActive)) {
      for (var item in s.items) {
        final key = item.product.id;
        if (productMap.containsKey(key)) {
          productMap[key]!.qty += item.quantity;
          productMap[key]!.revenue += item.total;
        } else {
          productMap[key] = _ProductRank(
            name: item.product.name,
            unit: item.product.unit,
            qty: item.quantity,
            revenue: item.total,
          );
        }
      }
    }

    final topProducts = productMap.values.toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));
    final displayTopProducts = topProducts.take(5).toList();

    final chartCard = Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'HOURLY SALES VELOCITY (8:00 - 20:00)',
                  style: GoogleFonts.oswald(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.bar_chart_rounded, size: 18, color: textSecondary),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 2,
                      getTitlesWidget: (value, meta) {
                        final h = value.toInt();
                        if (h % 2 != 0 && h != 8 && h != 20) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '$h:00',
                            style: GoogleFonts.inter(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                barGroups: hourlySales.entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value,
                        color: theme.colorScheme.primary,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );

    final topItemsCard = Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'TOP PURCHASED ITEMS',
                  style: GoogleFonts.oswald(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.star_outline_rounded, size: 18, color: textSecondary),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          if (displayTopProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text(
                  'No item sales recorded in this period.',
                  style: GoogleFonts.inter(color: textSecondary, fontSize: 12),
                ),
              ),
            )
          else
            Column(
              children: displayTopProducts.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final p = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.accentBlue.withValues(alpha: 0.15),
                        child: Text(
                          '$idx',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentBlue),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: GoogleFonts.inter(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${p.qty.toStringAsFixed(0)} ${p.unit} • GHS ${p.revenue.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(color: AppColors.emeraldSuccess, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 850) {
          return Column(
            children: [
              chartCard,
              const SizedBox(height: AppSpacing.l),
              topItemsCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: chartCard),
            const SizedBox(width: AppSpacing.l),
            Expanded(flex: 2, child: topItemsCard),
          ],
        );
      },
    );
  }

  Widget _buildTransactionCard(
    ThemeData theme,
    SaleRecord sale,
    Color cardBg,
    Color borderCol,
    Color textPrimary,
    Color textSecondary,
  ) {
    final paymentLabel = _getPaymentBadgeText(sale);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.xs),
        onTap: () => _showTransactionDetailModal(sale),
        leading: CircleAvatar(
          backgroundColor: AppColors.accentBlue.withValues(alpha: 0.12),
          child: Icon(
            sale.payments.length > 1 ? Icons.call_split : Icons.receipt_rounded,
            color: AppColors.accentBlue,
            size: 18,
          ),
        ),
        title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'INV #${sale.id.toUpperCase()}',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
            ),
            StatusBadge.fromStatus(sale.status.name),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                paymentLabel,
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${DateFormat('MMM dd, yyyy HH:mm').format(sale.timestamp)} • ${sale.items.length} items • Client: ${sale.customerName ?? "Walk-In"} • Cashier: ${sale.cashierName}',
            style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'GHS ${sale.totalAmount.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.emeraldSuccess,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Icon(Icons.chevron_right, color: textSecondary),
          ],
        ),
      ),
    );
  }

  String _getPaymentBadgeText(SaleRecord sale) {
    if (sale.payments.length > 1) return 'SPLIT PAYMENT (${sale.payments.length})';
    if (sale.payments.isEmpty) return 'CASH';
    switch (sale.payments.first.method) {
      case PaymentMethod.cash:
        return 'CASH';
      case PaymentMethod.mobileMoney:
        return sale.payments.first.isPaystack ? 'MOMO (PAYSTACK)' : 'MOBILE MONEY';
      case PaymentMethod.bankDeposit:
        return 'BANK TRANSFER';
    }
  }

  void _showTransactionDetailModal(SaleRecord sale) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: Row(
            children: [
              const Icon(Icons.receipt_long, color: AppColors.accentBlue),
              const SizedBox(width: AppSpacing.s),
              Text(
                'INVOICE DETAILED INSPECTION',
                style: GoogleFonts.oswald(fontWeight: FontWeight.bold, fontSize: 18, color: textPrimary),
              ),
              const Spacer(),
              StatusBadge.fromStatus(sale.status.name),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: textSecondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    child: Column(
                      children: [
                        _detailRow('Invoice Number:', '#${sale.id}', textPrimary, textSecondary),
                        _detailRow('Date & Time:', DateFormat('MMMM dd, yyyy HH:mm:ss').format(sale.timestamp), textPrimary, textSecondary),
                        _detailRow('Staff / Cashier:', sale.cashierName, textPrimary, textSecondary),
                        _detailRow('Customer Name:', sale.customerName ?? 'Walk-In Customer', textPrimary, textSecondary),
                        if (sale.customerPhone != null) _detailRow('Customer Phone:', sale.customerPhone!, textPrimary, textSecondary),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),

                  Text('PURCHASED LINE ITEMS', style: GoogleFonts.oswald(fontSize: 14, fontWeight: FontWeight.bold, color: textSecondary)),
                  const SizedBox(height: AppSpacing.s),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: borderCol),
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    child: Column(
                      children: sale.items.map((item) {
                        return ListTile(
                          dense: true,
                          title: Text(item.product.name, style: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Category: ${item.product.category} • Unit: GHS ${item.priceAtSale.toStringAsFixed(2)} x ${item.quantity}',
                            style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
                          ),
                          trailing: Text(
                            'GHS ${item.total.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(color: AppColors.emeraldSuccess, fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),

                  Text('PAYMENT METHOD SUMMARY', style: GoogleFonts.oswald(fontSize: 14, fontWeight: FontWeight.bold, color: textSecondary)),
                  const SizedBox(height: AppSpacing.s),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: textSecondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    child: Column(
                      children: [
                        ...sale.payments.map((p) => _detailRow(
                              'Payment Method (${p.method.name.toUpperCase()}):',
                              'GHS ${p.amount.toStringAsFixed(2)} ${p.reference != null ? "Ref: ${p.reference}" : ""}',
                              textPrimary,
                              textSecondary,
                            )),
                        Divider(color: borderCol),
                        _detailRow('Total Paid:', 'GHS ${sale.amountPaid.toStringAsFixed(2)}', textPrimary, textSecondary, isBold: true),
                        if (sale.effectiveChange > 0.01)
                          _detailRow('Change Given:', 'GHS ${sale.effectiveChange.toStringAsFixed(2)}', textPrimary, textSecondary, isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),

                  if (sale.status == SaleStatus.awaitingDeposit || sale.bankReceiptUrl != null) ...[
                    Text('BANK DEPOSIT SLIP INFORMATION', style: GoogleFonts.oswald(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber.shade700)),
                    const SizedBox(height: AppSpacing.s),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.m),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailRow('Bank Name:', 'UMB (Universal Merchant Bank)', textPrimary, textSecondary),
                          _detailRow('Account Name:', 'Mi-Corazon Enterprise', textPrimary, textSecondary),
                          _detailRow('Account Number:', '1111069263015', textPrimary, textSecondary),
                          if (sale.bankReceiptId != null) _detailRow('Deposit Ref ID:', sale.bankReceiptId!, textPrimary, textSecondary),
                          if (sale.bankReceiptUrl != null) ...[
                            const SizedBox(height: AppSpacing.s),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.m),
                              child: Image.network(
                                sale.bankReceiptUrl!,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, trace) => Text('Deposit photo preview unavailable.', style: TextStyle(color: textSecondary)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: [
                OutlinedButton.icon(
                  onPressed: () => ReceiptService.printReceipt(sale, context: context),
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('PRINT RECEIPT'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    String phone = sale.customerPhone ?? '';
                    if (phone.isEmpty) {
                      final ctrl = TextEditingController();
                      final entered = await showDialog<String>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Recipient Phone'),
                          content: TextField(
                            controller: ctrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'Customer Phone'),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
                            ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('SEND')),
                          ],
                        ),
                      );
                      if (entered == null || entered.isEmpty) return;
                      phone = entered;
                    }

                    final sent = await SmsService.sendReceiptSms(sale, customPhone: phone);
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(sent ? 'SMS Receipt sent to $phone!' : 'Failed to send SMS.'),
                          backgroundColor: sent ? AppColors.emeraldSuccess : AppColors.crimsonError,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.sms, size: 16),
                  label: const Text('SMS RECEIPT'),
                ),
                OutlinedButton.icon(
                  onPressed: () => ReceiptService.shareReceiptViaWhatsApp(sale, context: context, customerPhone: sale.customerPhone),
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('EXPORT / SHARE'),
                ),
                if (sale.isActive)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Request Reversal / Correction?'),
                          content: const Text('This will flag and reverse the sale transaction and restore inventory stock.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.crimsonError),
                              child: const Text('CONFIRM REVERSAL'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await ref.read(saleHistoryProvider.notifier).reverseSale(sale.id);
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Transaction successfully reversed!'),
                              backgroundColor: AppColors.emeraldSuccess,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('REQUEST REVERSAL'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.crimsonError, foregroundColor: Colors.white),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('CLOSE'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value, Color textPrimary, Color textSecondary, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: textSecondary)),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? AppColors.emeraldSuccess : textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductRank {
  final String name;
  final String unit;
  double qty;
  double revenue;

  _ProductRank({
    required this.name,
    required this.unit,
    required this.qty,
    required this.revenue,
  });
}
