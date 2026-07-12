import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/product_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/transaction_repository.dart';

class StockTrendPage extends StatefulWidget {
  const StockTrendPage({super.key});

  @override
  State<StockTrendPage> createState() => _StockTrendPageState();
}

class _StockTrendPageState extends State<StockTrendPage> {
  final ProductRepository _productRepository = ProductRepository();
  final TransactionRepository _transactionRepository = TransactionRepository();

  List<ProductModel> _products = [];
  String? _selectedProductId;
  DateTimeRange? _selectedDateRange;

  bool _isLoadingProducts = true;

  final BoxShadow _softShadow = BoxShadow(
    color: Colors.black.withOpacity(0.07),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  @override
  void initState() {
    super.initState();
    _selectedDateRange = _getDefaultDateRange();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _productRepository.getActiveProducts();

      if (!mounted) return;

      setState(() {
        _products = products;
        _selectedProductId = products.isNotEmpty ? products.first.id : null;
        _isLoadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingProducts = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat produk: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  ProductModel? _getSelectedProduct() {
    if (_selectedProductId == null) return null;

    final matchedProducts = _products.where(
      (product) => product.id == _selectedProductId,
    );

    if (matchedProducts.isEmpty) return null;

    return matchedProducts.first;
  }

  String _getSelectedProductName() {
    return _getSelectedProduct()?.name ?? '-';
  }

  String _getSelectedProductUnit() {
    return _getSelectedProduct()?.unit ?? 'karung';
  }

  int _getSelectedProductStock() {
    return _getSelectedProduct()?.totalStock ?? 0;
  }

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  DateTimeRange _getDefaultDateRange() {
    final now = DateTime.now();

    return DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: _endOfDay(now),
    );
  }

  DateTimeRange _getSelectedDateRange() {
    final selectedRange = _selectedDateRange ?? _getDefaultDateRange();

    return DateTimeRange(
      start: _startOfDay(selectedRange.start),
      end: _endOfDay(selectedRange.end),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  String _formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month';
  }

  String _getSelectedPeriodText() {
    final selectedRange = _getSelectedDateRange();

    return '${_formatDate(selectedRange.start)} - ${_formatDate(selectedRange.end)}';
  }

  String _buildDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<_DailyStockOut> _buildDailyStockOutData(
    List<TransactionModel> transactions,
  ) {
    if (_selectedProductId == null) {
      return [];
    }

    final selectedRange = _getSelectedDateRange();
    final startDate = _startOfDay(selectedRange.start);
    final endDate = _startOfDay(selectedRange.end);

    final stockOutTransactions = transactions.where((transaction) {
      final transactionDate = transaction.createdAt.toDate();
      final transactionDateOnly = _startOfDay(transactionDate);

      final matchProduct = transaction.productId == _selectedProductId;
      final matchType = transaction.type.toLowerCase().trim() == 'stock_out';
      final matchStartDate = !transactionDateOnly.isBefore(startDate);
      final matchEndDate = !transactionDateOnly.isAfter(endDate);

      return matchProduct && matchType && matchStartDate && matchEndDate;
    }).toList();

    if (stockOutTransactions.isEmpty) {
      return [];
    }

    final Map<String, _DailyStockOut> dailyMap = {};
    final totalDays = endDate.difference(startDate).inDays;

    if (totalDays >= 0 && totalDays <= 45) {
      for (int i = 0; i <= totalDays; i++) {
        final currentDate = startDate.add(Duration(days: i));
        final key = _buildDateKey(currentDate);

        dailyMap[key] = _DailyStockOut(
          date: currentDate,
          qty: 0,
        );
      }
    }

    for (final transaction in stockOutTransactions) {
      final dateTime = transaction.createdAt.toDate();

      final dateOnly = DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day,
      );

      final key = _buildDateKey(dateOnly);

      if (!dailyMap.containsKey(key)) {
        dailyMap[key] = _DailyStockOut(
          date: dateOnly,
          qty: 0,
        );
      }

      dailyMap[key] = _DailyStockOut(
        date: dateOnly,
        qty: dailyMap[key]!.qty + transaction.qty,
      );
    }

    final dailyData = dailyMap.values.toList();

    dailyData.sort((a, b) => a.date.compareTo(b.date));

    return dailyData;
  }

  _RegressionResult? _calculateLinearRegression(List<_DailyStockOut> data) {
    if (data.length < 3) {
      return null;
    }

    final n = data.length;

    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;

    for (int i = 0; i < n; i++) {
      final x = i.toDouble();
      final y = data[i].qty.toDouble();

      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    final denominator = (n * sumX2) - (sumX * sumX);

    if (denominator == 0) {
      return null;
    }

    final slope = ((n * sumXY) - (sumX * sumY)) / denominator;
    final intercept = (sumY - (slope * sumX)) / n;

    final totalQty = data.fold<int>(
      0,
      (total, item) => total + item.qty,
    );

    final averageQty = totalQty / data.length;

    final predictedDaily = <_PredictedStockOut>[];
    double estimatedNext7Days = 0;

    final lastDate = data.last.date;

    for (int i = 0; i < 7; i++) {
      final x = n + i;
      final rawPrediction = intercept + (slope * x);
      final double prediction = rawPrediction < 0 ? 0.0 : rawPrediction;
      final roundedPrediction = prediction.round();

      predictedDaily.add(
        _PredictedStockOut(
          date: lastDate.add(Duration(days: i + 1)),
          qty: roundedPrediction,
        ),
      );

      estimatedNext7Days += prediction;
    }

    String trendStatus;

    if (slope > 0.1) {
      trendStatus = 'Pengeluaran stok cenderung meningkat.';
    } else if (slope < -0.1) {
      trendStatus = 'Pengeluaran stok cenderung menurun.';
    } else {
      trendStatus = 'Pengeluaran stok relatif stabil.';
    }

    return _RegressionResult(
      slope: slope,
      intercept: intercept,
      trendStatus: trendStatus,
      totalQty: totalQty,
      averageQty: averageQty,
      estimatedNext7Days: estimatedNext7Days,
      predictedDaily: predictedDaily,
    );
  }

  String _getTrendLabel(double slope) {
    if (slope > 0.1) return 'Meningkat';
    if (slope < -0.1) return 'Menurun';
    return 'Stabil';
  }

  Color _getTrendColor(double slope) {
    if (slope > 0.1) return Colors.green.shade600;
    if (slope < -0.1) return Colors.red.shade400;
    return Colors.orange.shade500;
  }

  IconData _getTrendIcon(double slope) {
    if (slope > 0.1) return Icons.trending_up;
    if (slope < -0.1) return Icons.trending_down;
    return Icons.trending_flat;
  }

  String _getPredictionStatus({
    required int currentStock,
    required int estimatedNeed,
  }) {
    if (currentStock <= 0) {
      return 'Perlu Restock';
    }

    if (currentStock < estimatedNeed) {
      return 'Perlu Restock';
    }

    if (currentStock <= (estimatedNeed * 1.3).ceil()) {
      return 'Perlu Dipantau';
    }

    return 'Stok Aman';
  }

  Color _getPredictionColor(String status) {
    if (status == 'Perlu Restock') return Colors.red.shade500;
    if (status == 'Perlu Dipantau') return Colors.orange.shade500;
    return Colors.green.shade600;
  }

  IconData _getPredictionIcon(String status) {
    if (status == 'Perlu Restock') return Icons.warning_amber_rounded;
    if (status == 'Perlu Dipantau') return Icons.visibility_outlined;
    return Icons.check_circle_outline;
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF038E1B),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _selectedDateRange = picked;
    });
  }

  Widget _buildCleanCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color color = Colors.white,
    Color borderColor = const Color(0xFFE5E5E5),
  }) {
    return Container(
      width: double.infinity,
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        boxShadow: [_softShadow],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductAndPeriodFilter() {
    if (_products.isEmpty) {
      return _buildCleanCard(
        color: Colors.grey.shade50,
        borderColor: Colors.grey.shade300,
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.inventory_2_outlined, color: Colors.grey),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Belum ada produk aktif untuk dianalisis.',
                style: TextStyle(color: Colors.black87, height: 1.3),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Filter Analisis',
          subtitle:
              'Pilih produk dan periode custom transaksi stok keluar yang ingin dianalisis.',
        ),
        _buildCleanCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedProductId,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                decoration: InputDecoration(
                  labelText: 'Produk / Merk Beras',
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8F8F8),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFDADADA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF038E1B)),
                  ),
                ),
                items: _products.map((product) {
                  return DropdownMenuItem<String>(
                    value: product.id,
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _selectedProductId = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Periode Analisis',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDADADA)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 17,
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(
                        Icons.date_range_outlined,
                        color: Color(0xFF038E1B),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _getSelectedPeriodText(),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildSmallGradientButton(
                      label: 'Pilih',
                      icon: Icons.calendar_month,
                      onTap: _pickCustomDateRange,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Periode custom digunakan sebagai batas data transaksi stok keluar yang dianalisis.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallGradientButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 34,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF015816),
            Color(0xFF038E1B),
            Color(0xFF84E977),
          ],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisResult({
    required List<_DailyStockOut> dailyData,
    required _RegressionResult? result,
  }) {
    if (_selectedProductId == null) {
      return const SizedBox.shrink();
    }

    if (dailyData.isEmpty) {
      return _buildEmptyTrendDataCard();
    }

    if (dailyData.length < 3 || result == null) {
      return _buildNotEnoughDataCard(dailyData.length);
    }

    final trendColor = _getTrendColor(result.slope);
    final trendLabel = _getTrendLabel(result.slope);
    final trendIcon = _getTrendIcon(result.slope);

    final unit = _getSelectedProductUnit();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Dashboard Analisis Tren',
          subtitle:
              'Ringkasan hasil perhitungan linear regression berdasarkan data aktual stok keluar pada periode custom.',
        ),
        _buildCleanCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: trendColor.withOpacity(0.15),
                    child: Icon(trendIcon, color: trendColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status Tren',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result.trendStatus,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Colors.black54,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(text: trendLabel, color: trendColor),
                ],
              ),
              const SizedBox(height: 16),
              _buildResultRow(
                icon: Icons.inventory_2_outlined,
                label: 'Produk',
                value: _getSelectedProductName(),
              ),
              _buildResultRow(
                icon: Icons.date_range_outlined,
                label: 'Periode',
                value: _getSelectedPeriodText(),
              ),
              _buildResultRow(
                icon: Icons.calendar_today_outlined,
                label: 'Jumlah Data Harian',
                value: '${dailyData.length} hari',
              ),
              _buildResultRow(
                icon: Icons.arrow_upward,
                label: 'Total Stok Keluar',
                value: '${result.totalQty} $unit',
              ),
              _buildResultRow(
                icon: Icons.bar_chart,
                label: 'Rata-rata per Hari',
                value: '${result.averageQty.toStringAsFixed(0)} $unit',
              ),
              _buildResultRow(
                icon: Icons.functions,
                label: 'Nilai Slope',
                value: result.slope.toStringAsFixed(3),
              ),
              _buildResultRow(
                icon: Icons.calculate_outlined,
                label: 'Nilai Intercept',
                value: result.intercept.toStringAsFixed(3),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nilai slope menunjukkan arah perubahan stok keluar pada periode custom. Slope positif berarti meningkat, slope negatif berarti menurun, sedangkan nilai mendekati 0 menunjukkan tren relatif stabil.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrendChartSection({
    required List<_DailyStockOut> dailyData,
    required _RegressionResult? result,
  }) {
    if (dailyData.isEmpty) {
      return const SizedBox.shrink();
    }

    final actualPoints = dailyData.map((item) {
      return _TrendChartPoint(
        label: _formatShortDate(item.date),
        fullLabel: _formatDate(item.date),
        value: item.qty.toDouble(),
      );
    }).toList();

    final chartWidth = math.max(
      MediaQuery.of(context).size.width - 96,
      actualPoints.length * 48.0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Grafik Tren Stok Keluar',
          subtitle:
              'Grafik utama hanya menampilkan data aktual stok keluar dan garis tren regresi pada periode custom.',
        ),
        _buildCleanCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sumbu Y: Total Stok Keluar (Karung)',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: chartWidth,
                  height: 250,
                  child: CustomPaint(
                    painter: _TrendLineChartPainter(
                      actualPoints: actualPoints,
                      regressionResult: result,
                      actualColor: const Color(0xFF038E1B),
                      trendColor: Colors.orange.shade600,
                      gridColor: Colors.black.withOpacity(0.12),
                      textColor: Colors.black54,
                    ),
                    child: Container(),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Sumbu X: Tanggal',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildLegendItem(
                    color: const Color(0xFF038E1B),
                    label: 'Data Aktual',
                    isDashed: false,
                  ),
                  _buildLegendItem(
                    color: Colors.orange.shade600,
                    label: 'Garis Tren',
                    isDashed: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionButton({
    required List<_DailyStockOut> dailyData,
    required _RegressionResult? result,
  }) {
    final canPredict = dailyData.length >= 3 && result != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Prediksi Stok Keluar',
          subtitle:
              'Prediksi 7 hari ke depan ditampilkan terpisah agar halaman utama tetap fokus pada analisis tren aktual.',
        ),
        Opacity(
          opacity: canPredict ? 1 : 0.55,
          child: Container(
            width: double.infinity,
            height: 46,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF015816),
                  Color(0xFF038E1B),
                  Color(0xFF84E977),
                ],
                stops: [0.0, 0.55, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.11),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canPredict
                    ? () {
                        _showPredictionBottomSheet(
                          dailyData: dailyData,
                          result: result,
                        );
                      }
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Minimal diperlukan 3 hari data stok keluar untuk membuat prediksi.',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_graph_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Prediksi Stok Keluar 7 Hari',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showPredictionBottomSheet({
    required List<_DailyStockOut> dailyData,
    required _RegressionResult result,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.55,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Prediksi Stok Keluar 7 Hari',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.of(bottomSheetContext).pop();
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Prediksi dihitung berdasarkan data aktual stok keluar pada periode ${_getSelectedPeriodText()}.',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildPredictionSummaryCard(result),
                        const SizedBox(height: 20),
                        _buildPredictionChart(result),
                        const SizedBox(height: 20),
                        _buildPredictionDailyList(result),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPredictionSummaryCard(_RegressionResult result) {
    final unit = _getSelectedProductUnit();
    final currentStock = _getSelectedProductStock();
    final estimatedNeed = result.estimatedNext7Days.ceil();
    final additionalNeed = math.max(0, estimatedNeed - currentStock);

    final predictionStatus = _getPredictionStatus(
      currentStock: currentStock,
      estimatedNeed: estimatedNeed,
    );

    final statusColor = _getPredictionColor(predictionStatus);
    final statusIcon = _getPredictionIcon(predictionStatus);

    return _buildCleanCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: statusColor.withOpacity(0.15),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  predictionStatus,
                  style: TextStyle(
                    fontSize: 15,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildStatusChip(
                text: additionalNeed > 0 ? 'Restock' : 'Aman',
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildResultRow(
            icon: Icons.inventory_2_outlined,
            label: 'Produk',
            value: _getSelectedProductName(),
          ),
          _buildResultRow(
            icon: Icons.date_range_outlined,
            label: 'Periode Data',
            value: _getSelectedPeriodText(),
          ),
          _buildResultRow(
            icon: Icons.inventory_outlined,
            label: 'Stok Saat Ini',
            value: '$currentStock $unit',
          ),
          _buildResultRow(
            icon: Icons.next_week_outlined,
            label: 'Estimasi Kebutuhan 7 Hari',
            value: '$estimatedNeed $unit',
          ),
          _buildResultRow(
            icon: Icons.add_box_outlined,
            label: 'Saran Tambahan Stok',
            value:
                additionalNeed == 0 ? 'Tidak perlu' : '$additionalNeed $unit',
          ),
          _buildResultRow(
            icon: Icons.timeline_outlined,
            label: 'Rata-rata Historis',
            value: '${result.averageQty.toStringAsFixed(0)} $unit/hari',
          ),
          const SizedBox(height: 10),
          const Text(
            'Prediksi ini hanya digunakan sebagai informasi pendukung untuk memperkirakan kebutuhan stok. Keputusan pembelian tetap disesuaikan dengan kondisi nyata di toko.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionChart(_RegressionResult result) {
    final predictionPoints = result.predictedDaily.map((item) {
      return _TrendChartPoint(
        label: _formatShortDate(item.date),
        fullLabel: _formatDate(item.date),
        value: item.qty.toDouble(),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Grafik Prediksi 7 Hari',
          subtitle:
              'Grafik ini menampilkan estimasi stok keluar selama 7 hari ke depan.',
        ),
        _buildCleanCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sumbu Y: Prediksi Stok Keluar (Karung)',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 250,
                child: CustomPaint(
                  painter: _PredictionLineChartPainter(
                    predictionPoints: predictionPoints,
                    predictionColor: Colors.deepPurple.shade500,
                    forecastAreaColor: Colors.deepPurple.shade50,
                    gridColor: Colors.black.withOpacity(0.12),
                    textColor: Colors.black54,
                  ),
                  child: Container(),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Sumbu X: Tanggal Prediksi',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: _buildLegendItem(
                  color: Colors.deepPurple.shade500,
                  label: 'Prediksi Stok Keluar',
                  isDashed: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionDailyList(_RegressionResult result) {
    final unit = _getSelectedProductUnit();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Rincian Prediksi Harian',
          subtitle:
              'Rincian estimasi stok keluar untuk masing-masing hari prediksi.',
        ),
        ...result.predictedDaily.map((item) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.045),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.deepPurple.withOpacity(0.14),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.deepPurple.withOpacity(0.15),
                    child: const Icon(
                      Icons.auto_graph,
                      color: Colors.deepPurple,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _formatDate(item.date),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  _buildStatusChip(
                    text: '${item.qty} $unit',
                    color: Colors.deepPurple.shade500,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required bool isDashed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 8,
          child: CustomPaint(
            painter: _LegendLinePainter(
              color: color,
              isDashed: isDashed,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyTrendDataCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.orange.withOpacity(0.15),
            child: const Icon(Icons.info_outline, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Belum ada transaksi stok keluar untuk produk ${_getSelectedProductName()} pada periode ${_getSelectedPeriodText()}. Silakan pilih periode lain atau tambahkan transaksi stok keluar terlebih dahulu.',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotEnoughDataCard(int dailyDataCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.orange.withOpacity(0.15),
            child: const Icon(Icons.info_outline, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Produk ${_getSelectedProductName()} baru memiliki $dailyDataCount hari data stok keluar pada periode ini. Minimal diperlukan 3 hari data untuk melakukan analisis tren dan prediksi kebutuhan stok.',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDailyDataList(List<_DailyStockOut> dailyData) {
    if (dailyData.isEmpty) return const SizedBox.shrink();

    final unit = _getSelectedProductUnit();
    final totalQty = dailyData.fold<int>(0, (total, item) => total + item.qty);
    final activeDays = dailyData.where((item) => item.qty > 0).length;
    final maxQty = dailyData.fold<int>(
      0,
      (maxValue, item) => math.max(maxValue, item.qty),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Data Harian Stok Keluar',
          subtitle:
              'Rekap harian yang digunakan dalam analisis tren. Daftar dibuat compact agar tidak terlalu panjang ke bawah.',
        ),
        _buildCleanCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildDailyMiniSummary(
                      label: 'Total',
                      value: '$totalQty $unit',
                      icon: Icons.inventory_2_outlined,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDailyMiniSummary(
                      label: 'Hari Aktif',
                      value: '$activeDays hari',
                      icon: Icons.event_available_outlined,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 260,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: dailyData.length,
                  separatorBuilder: (context, index) {
                    return const SizedBox(height: 8);
                  },
                  itemBuilder: (context, index) {
                    final item = dailyData[index];

                    return _buildCompactDailyRow(
                      item: item,
                      unit: unit,
                      maxQty: maxQty,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Data dengan nilai 0 menunjukkan tidak ada stok keluar pada tanggal tersebut.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyMiniSummary({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDailyRow({
    required _DailyStockOut item,
    required String unit,
    required int maxQty,
  }) {
    final ratio = maxQty <= 0 ? 0.0 : item.qty / maxQty;
    final barColor = item.qty > 0 ? Colors.blue.shade600 : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              _formatShortDate(item.date),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: ratio.clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: Text(
              '${item.qty} $unit',
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: item.qty > 0 ? Colors.black87 : Colors.black45,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.green),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Text(
            'Gagal memuat transaksi: $error',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60.0),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.keyboard_double_arrow_left,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'ANALISIS TREN',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF015816),
                Color(0xFF038E1B),
                Color(0xFF84E977),
              ],
              stops: [0.0, 0.5, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(),
      body: _isLoadingProducts
          ? _buildLoadingState()
          : StreamBuilder<List<TransactionModel>>(
              stream: _transactionRepository.getTransactionsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return _buildLoadingState();
                }

                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error);
                }

                final transactions = snapshot.data ?? [];
                final dailyData = _buildDailyStockOutData(transactions);
                final regressionResult = _calculateLinearRegression(dailyData);

                return SafeArea(
                  child: SingleChildScrollView(
                    key: const PageStorageKey<String>('stock_trend_scroll'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    physics: const ClampingScrollPhysics(),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.black12, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProductAndPeriodFilter(),
                              const SizedBox(height: 24),
                              _buildAnalysisResult(
                                dailyData: dailyData,
                                result: regressionResult,
                              ),
                              const SizedBox(height: 24),
                              _buildTrendChartSection(
                                dailyData: dailyData,
                                result: regressionResult,
                              ),
                              const SizedBox(height: 24),
                              _buildPredictionButton(
                                dailyData: dailyData,
                                result: regressionResult,
                              ),
                              const SizedBox(height: 24),
                              _buildDailyDataList(dailyData),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _DailyStockOut {
  final DateTime date;
  final int qty;

  _DailyStockOut({
    required this.date,
    required this.qty,
  });
}

class _PredictedStockOut {
  final DateTime date;
  final int qty;

  _PredictedStockOut({
    required this.date,
    required this.qty,
  });
}

class _RegressionResult {
  final double slope;
  final double intercept;
  final String trendStatus;
  final int totalQty;
  final double averageQty;
  final double estimatedNext7Days;
  final List<_PredictedStockOut> predictedDaily;

  _RegressionResult({
    required this.slope,
    required this.intercept,
    required this.trendStatus,
    required this.totalQty,
    required this.averageQty,
    required this.estimatedNext7Days,
    required this.predictedDaily,
  });
}

class _TrendChartPoint {
  final String label;
  final String fullLabel;
  final double value;

  _TrendChartPoint({
    required this.label,
    required this.fullLabel,
    required this.value,
  });
}

class _LegendLinePainter extends CustomPainter {
  final Color color;
  final bool isDashed;

  _LegendLinePainter({
    required this.color,
    required this.isDashed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    if (!isDashed) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }

    double startX = 0;
    const dashWidth = 6;
    const dashSpace = 4;

    while (startX < size.width) {
      final endX = math.min(startX + dashWidth, size.width);

      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(endX.toDouble(), size.height / 2),
        paint,
      );

      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _LegendLinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isDashed != isDashed;
  }
}

class _TrendLineChartPainter extends CustomPainter {
  final List<_TrendChartPoint> actualPoints;
  final _RegressionResult? regressionResult;
  final Color actualColor;
  final Color trendColor;
  final Color gridColor;
  final Color textColor;

  _TrendLineChartPainter({
    required this.actualPoints,
    required this.regressionResult,
    required this.actualColor,
    required this.trendColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (actualPoints.isEmpty) return;

    final chartRect = Rect.fromLTWH(
      36,
      26,
      size.width - 46,
      size.height - 62,
    );

    final maxActualValue = actualPoints.fold<double>(
      0,
      (maxValue, item) => math.max(maxValue, item.value),
    );

    double maxTrendValue = 0;

    if (regressionResult != null && actualPoints.length >= 3) {
      for (int i = 0; i < actualPoints.length; i++) {
        final trendValue =
            regressionResult!.intercept + (regressionResult!.slope * i);
        maxTrendValue = math.max(maxTrendValue, trendValue);
      }
    }

    final maxValueBase = math.max(maxActualValue, maxTrendValue);
    final maxValue = maxValueBase <= 0 ? 1.0 : maxValueBase * 1.25;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = Colors.black.withOpacity(0.28)
      ..strokeWidth = 1.2;

    final actualPaint = Paint()
      ..color = actualColor
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final trendPaint = Paint()
      ..color = trendColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final actualPointPaint = Paint()
      ..color = actualColor
      ..style = PaintingStyle.fill;

    final actualHaloPaint = Paint()
      ..color = actualColor.withOpacity(0.13)
      ..style = PaintingStyle.fill;

    double getX(int index) {
      if (actualPoints.length == 1) return chartRect.center.dx;

      return chartRect.left +
          (chartRect.width / (actualPoints.length - 1)) * index;
    }

    double getY(double value) {
      return chartRect.bottom - ((value / maxValue) * chartRect.height);
    }

    for (int i = 0; i <= 4; i++) {
      final y = chartRect.top + (chartRect.height / 4) * i;

      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );

      final labelValue = maxValue - ((maxValue / 4) * i);

      _drawText(
        canvas: canvas,
        text: labelValue.round().toString(),
        offset: Offset(0, y - 8),
        color: textColor,
        fontSize: 9,
        maxWidth: 30,
        textAlign: TextAlign.right,
      );
    }

    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );

    canvas.drawLine(
      Offset(chartRect.left, chartRect.top),
      Offset(chartRect.left, chartRect.bottom),
      axisPaint,
    );

    final actualOffsets = <Offset>[];

    for (int i = 0; i < actualPoints.length; i++) {
      actualOffsets.add(
        Offset(
          getX(i),
          getY(actualPoints[i].value),
        ),
      );
    }

    if (actualOffsets.length > 1) {
      final actualPath = Path();

      for (int i = 0; i < actualOffsets.length; i++) {
        if (i == 0) {
          actualPath.moveTo(actualOffsets[i].dx, actualOffsets[i].dy);
        } else {
          actualPath.lineTo(actualOffsets[i].dx, actualOffsets[i].dy);
        }
      }

      canvas.drawPath(actualPath, actualPaint);
    }

    if (regressionResult != null && actualPoints.length >= 3) {
      final trendPath = Path();

      for (int i = 0; i < actualPoints.length; i++) {
        final trendValue =
            regressionResult!.intercept + (regressionResult!.slope * i);

        final double safeTrendValue = trendValue < 0 ? 0.0 : trendValue;

        final x = getX(i);
        final y = getY(safeTrendValue);

        if (i == 0) {
          trendPath.moveTo(x, y);
        } else {
          trendPath.lineTo(x, y);
        }
      }

      _drawDashedPath(
        canvas,
        trendPath,
        trendPaint,
      );
    }

    final labelStep = actualPoints.length <= 10
        ? 1
        : math.max(1, (actualPoints.length / 8).ceil());

    for (int i = 0; i < actualOffsets.length; i++) {
      final offset = actualOffsets[i];

      canvas.drawCircle(offset, 6, actualHaloPaint);
      canvas.drawCircle(offset, 3.8, actualPointPaint);

      final showValue = actualPoints.length <= 14 || actualPoints[i].value > 0;

      if (showValue) {
        _drawText(
          canvas: canvas,
          text: actualPoints[i].value.round().toString(),
          offset: Offset(offset.dx - 15, offset.dy - 22),
          color: actualColor,
          fontSize: 8.5,
          maxWidth: 30,
          textAlign: TextAlign.center,
        );
      }

      final showDateLabel = i % labelStep == 0 || i == actualOffsets.length - 1;

      if (showDateLabel) {
        _drawText(
          canvas: canvas,
          text: actualPoints[i].label,
          offset: Offset(offset.dx - 15, chartRect.bottom + 10),
          color: textColor,
          fontSize: 8,
          maxWidth: 30,
          textAlign: TextAlign.center,
        );
      }
    }
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    double dashWidth = 7,
    double dashSpace = 4,
  }) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;

      while (distance < metric.length) {
        final nextDistance = math.min(distance + dashWidth, metric.length);
        final extractPath = metric.extractPath(distance, nextDistance);

        canvas.drawPath(extractPath, paint);

        distance += dashWidth + dashSpace;
      }
    }
  }

  void _drawText({
    required Canvas canvas,
    required String text,
    required Offset offset,
    required Color color,
    required double fontSize,
    required double maxWidth,
    TextAlign textAlign = TextAlign.left,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: 1,
    );

    textPainter.layout(maxWidth: maxWidth);
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TrendLineChartPainter oldDelegate) {
    return oldDelegate.actualPoints != actualPoints ||
        oldDelegate.regressionResult != regressionResult ||
        oldDelegate.actualColor != actualColor ||
        oldDelegate.trendColor != trendColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor;
  }
}

class _PredictionLineChartPainter extends CustomPainter {
  final List<_TrendChartPoint> predictionPoints;
  final Color predictionColor;
  final Color forecastAreaColor;
  final Color gridColor;
  final Color textColor;

  _PredictionLineChartPainter({
    required this.predictionPoints,
    required this.predictionColor,
    required this.forecastAreaColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (predictionPoints.isEmpty) return;

    final chartRect = Rect.fromLTWH(
      36,
      26,
      size.width - 46,
      size.height - 62,
    );

    final maxPredictionValue = predictionPoints.fold<double>(
      0,
      (maxValue, item) => math.max(maxValue, item.value),
    );

    final maxValue = maxPredictionValue <= 0 ? 1.0 : maxPredictionValue * 1.25;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = Colors.black.withOpacity(0.28)
      ..strokeWidth = 1.2;

    final predictionPaint = Paint()
      ..color = predictionColor
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final predictionPointPaint = Paint()
      ..color = predictionColor
      ..style = PaintingStyle.fill;

    final predictionHaloPaint = Paint()
      ..color = predictionColor.withOpacity(0.13)
      ..style = PaintingStyle.fill;

    double getX(int index) {
      if (predictionPoints.length == 1) return chartRect.center.dx;

      return chartRect.left +
          (chartRect.width / (predictionPoints.length - 1)) * index;
    }

    double getY(double value) {
      return chartRect.bottom - ((value / maxValue) * chartRect.height);
    }

    canvas.drawRect(
      chartRect,
      Paint()
        ..color = forecastAreaColor.withOpacity(0.75)
        ..style = PaintingStyle.fill,
    );

    for (int i = 0; i <= 4; i++) {
      final y = chartRect.top + (chartRect.height / 4) * i;

      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );

      final labelValue = maxValue - ((maxValue / 4) * i);

      _drawText(
        canvas: canvas,
        text: labelValue.round().toString(),
        offset: Offset(0, y - 8),
        color: textColor,
        fontSize: 9,
        maxWidth: 30,
        textAlign: TextAlign.right,
      );
    }

    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );

    canvas.drawLine(
      Offset(chartRect.left, chartRect.top),
      Offset(chartRect.left, chartRect.bottom),
      axisPaint,
    );

    final predictionOffsets = <Offset>[];

    for (int i = 0; i < predictionPoints.length; i++) {
      predictionOffsets.add(
        Offset(
          getX(i),
          getY(predictionPoints[i].value),
        ),
      );
    }

    if (predictionOffsets.length > 1) {
      final predictionPath = Path();

      for (int i = 0; i < predictionOffsets.length; i++) {
        if (i == 0) {
          predictionPath.moveTo(
            predictionOffsets[i].dx,
            predictionOffsets[i].dy,
          );
        } else {
          predictionPath.lineTo(
            predictionOffsets[i].dx,
            predictionOffsets[i].dy,
          );
        }
      }

      canvas.drawPath(predictionPath, predictionPaint);
    }

    for (int i = 0; i < predictionOffsets.length; i++) {
      final offset = predictionOffsets[i];

      canvas.drawCircle(offset, 6, predictionHaloPaint);
      canvas.drawCircle(offset, 3.8, predictionPointPaint);

      _drawText(
        canvas: canvas,
        text: predictionPoints[i].value.round().toString(),
        offset: Offset(offset.dx - 15, offset.dy - 22),
        color: predictionColor,
        fontSize: 8.5,
        maxWidth: 30,
        textAlign: TextAlign.center,
      );

      _drawText(
        canvas: canvas,
        text: predictionPoints[i].label,
        offset: Offset(offset.dx - 15, chartRect.bottom + 10),
        color: textColor,
        fontSize: 8,
        maxWidth: 30,
        textAlign: TextAlign.center,
      );
    }
  }

  void _drawText({
    required Canvas canvas,
    required String text,
    required Offset offset,
    required Color color,
    required double fontSize,
    required double maxWidth,
    TextAlign textAlign = TextAlign.left,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: 1,
    );

    textPainter.layout(maxWidth: maxWidth);
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _PredictionLineChartPainter oldDelegate) {
    return oldDelegate.predictionPoints != predictionPoints ||
        oldDelegate.predictionColor != predictionColor ||
        oldDelegate.forecastAreaColor != forecastAreaColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor;
  }
}
