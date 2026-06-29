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
  bool _isLoadingProducts = true;

  final BoxShadow _softShadow = BoxShadow(
    color: Colors.black.withOpacity(0.07),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  @override
  void initState() {
    super.initState();
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

  List<_DailyStockOut> _buildDailyStockOutData(
    List<TransactionModel> transactions,
  ) {
    final Map<String, _DailyStockOut> dailyMap = {};

    final stockOutTransactions = transactions.where((transaction) {
      return transaction.type.toLowerCase().trim() == 'stock_out' &&
          transaction.productId == _selectedProductId;
    }).toList();

    for (final transaction in stockOutTransactions) {
      final dateTime = transaction.createdAt.toDate();

      final dateOnly = DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day,
      );

      final key =
          '${dateOnly.year}-${dateOnly.month.toString().padLeft(2, '0')}-${dateOnly.day.toString().padLeft(2, '0')}';

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

  Widget _buildProductFilter() {
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
          title: 'Pilih Produk',
          subtitle:
              'Pilih produk atau merk beras yang ingin dianalisis berdasarkan transaksi stok keluar.',
        ),
        _buildCleanCard(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<String>(
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
        ),
      ],
    );
  }

  Widget _buildAnalysisResult({
    required List<_DailyStockOut> dailyData,
    required _RegressionResult? result,
  }) {
    if (_selectedProductId == null) {
      return const SizedBox.shrink();
    }

    if (dailyData.length < 3 || result == null) {
      return _buildNotEnoughDataCard(dailyData.length);
    }

    final trendColor = _getTrendColor(result.slope);
    final trendLabel = _getTrendLabel(result.slope);
    final trendIcon = _getTrendIcon(result.slope);

    final unit = _getSelectedProductUnit();
    final currentStock = _getSelectedProductStock();
    final estimatedNeed = result.estimatedNext7Days.ceil();
    final additionalNeed = math.max(0, estimatedNeed - currentStock);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Dashboard Analisis',
          subtitle:
              'Ringkasan hasil perhitungan linear regression dari data stok keluar harian.',
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
                icon: Icons.inventory_outlined,
                label: 'Stok Saat Ini',
                value: '$currentStock $unit',
              ),
              _buildResultRow(
                icon: Icons.auto_graph_outlined,
                label: 'Estimasi Kebutuhan 7 Hari',
                value: '$estimatedNeed $unit',
              ),
              _buildResultRow(
                icon: Icons.add_shopping_cart_outlined,
                label: 'Saran Tambahan Stok',
                value: additionalNeed == 0
                    ? 'Tidak perlu'
                    : '$additionalNeed $unit',
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
                'Nilai slope menunjukkan arah perubahan stok keluar. Slope positif berarti pengeluaran cenderung meningkat, slope negatif berarti menurun, sedangkan nilai mendekati 0 menunjukkan tren relatif stabil. Hasil prediksi bersifat pendukung dan bukan keputusan otomatis.',
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

  Widget _buildPredictionCard({
    required _RegressionResult? result,
    required List<_DailyStockOut> dailyData,
  }) {
    if (result == null || dailyData.length < 3) {
      return const SizedBox.shrink();
    }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Prediksi Kebutuhan Stok',
          subtitle:
              'Prediksi dihitung dari pola stok keluar harian selama 7 hari berikutnya secara total, bukan per hari.',
        ),
        _buildCleanCard(
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
                label: 'Stok tersedia',
                value: '$currentStock $unit',
              ),
              _buildResultRow(
                icon: Icons.next_week_outlined,
                label: 'Estimasi kebutuhan 7 hari',
                value: '$estimatedNeed $unit',
              ),
              _buildResultRow(
                icon: Icons.add_box_outlined,
                label: 'Kebutuhan tambahan',
                value:
                    additionalNeed == 0 ? '0 $unit' : '$additionalNeed $unit',
              ),
              _buildResultRow(
                icon: Icons.timeline_outlined,
                label: 'Rata-rata historis',
                value: '${result.averageQty.toStringAsFixed(0)} $unit/hari',
              ),
              const SizedBox(height: 10),
              const Text(
                'Rekomendasi ini hanya membantu pemilik toko memperkirakan kebutuhan stok. Keputusan pembelian tetap disesuaikan dengan kondisi toko dan persediaan nyata di gudang.',
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

    final predictionPoints = result == null || dailyData.length < 3
        ? <_TrendChartPoint>[]
        : result.predictedDaily.map((item) {
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
          title: 'Grafik Tren dan Prediksi Stok Keluar 7 Hari ke Depan',
          subtitle:
              'Grafik menampilkan data aktual, garis tren regresi, dan prediksi stok keluar selama 7 hari berikutnya.',
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
              SizedBox(
                width: double.infinity,
                height: 260,
                child: CustomPaint(
                  painter: _TrendLineChartPainter(
                    actualPoints: actualPoints,
                    predictionPoints: predictionPoints,
                    regressionResult: result,
                    actualColor: const Color(0xFF038E1B),
                    trendColor: Colors.orange.shade600,
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
                  _buildLegendItem(
                    color: Colors.deepPurple.shade500,
                    label: 'Prediksi 7 Hari',
                    isDashed: false,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Area berwarna samar menunjukkan periode forecast 7 hari setelah data aktual terakhir.',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Data Belum Cukup',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Produk ${_getSelectedProductName()} baru memiliki $dailyDataCount hari data stok keluar. Minimal diperlukan 3 hari data transaksi stok keluar untuk melakukan analisis tren dan prediksi kebutuhan stok.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                ),
              ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Data Harian Stok Keluar',
          subtitle:
              'Data harian diambil dari transaksi stok keluar berdasarkan produk yang dipilih.',
        ),
        ...dailyData.map((item) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.045),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.blue.withOpacity(0.14),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blue.withOpacity(0.15),
                    child: const Icon(
                      Icons.calendar_today,
                      color: Colors.blue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(item.date),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Stok Keluar: ${item.qty} $unit',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(
                    text: '${item.qty} $unit',
                    color: Colors.blue.shade600,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
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
                if (snapshot.connectionState == ConnectionState.waiting) {
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
                              _buildProductFilter(),
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
                              _buildPredictionCard(
                                result: regressionResult,
                                dailyData: dailyData,
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
  final List<_TrendChartPoint> predictionPoints;
  final _RegressionResult? regressionResult;
  final Color actualColor;
  final Color trendColor;
  final Color predictionColor;
  final Color forecastAreaColor;
  final Color gridColor;
  final Color textColor;

  _TrendLineChartPainter({
    required this.actualPoints,
    required this.predictionPoints,
    required this.regressionResult,
    required this.actualColor,
    required this.trendColor,
    required this.predictionColor,
    required this.forecastAreaColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final allPoints = <_TrendChartPoint>[
      ...actualPoints,
      ...predictionPoints,
    ];

    if (allPoints.isEmpty) return;

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

    final maxPredictionValue = predictionPoints.fold<double>(
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

    final maxValueBase = math.max(
      math.max(maxActualValue, maxPredictionValue),
      maxTrendValue,
    );

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

    final predictionPaint = Paint()
      ..color = predictionColor
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final actualPointPaint = Paint()
      ..color = actualColor
      ..style = PaintingStyle.fill;

    final predictionPointPaint = Paint()
      ..color = predictionColor
      ..style = PaintingStyle.fill;

    final actualHaloPaint = Paint()
      ..color = actualColor.withOpacity(0.13)
      ..style = PaintingStyle.fill;

    final predictionHaloPaint = Paint()
      ..color = predictionColor.withOpacity(0.13)
      ..style = PaintingStyle.fill;

    double getX(int index) {
      if (allPoints.length == 1) return chartRect.center.dx;

      return chartRect.left +
          (chartRect.width / (allPoints.length - 1)) * index;
    }

    double getY(double value) {
      return chartRect.bottom - ((value / maxValue) * chartRect.height);
    }

    if (predictionPoints.isNotEmpty && actualPoints.isNotEmpty) {
      final lastActualIndex = actualPoints.length - 1;
      final firstPredictionIndex = actualPoints.length;

      final lastActualX = getX(lastActualIndex);
      final firstPredictionX = getX(firstPredictionIndex);
      final forecastStartX = (lastActualX + firstPredictionX) / 2;

      final forecastRect = Rect.fromLTRB(
        forecastStartX,
        chartRect.top,
        chartRect.right,
        chartRect.bottom,
      );

      canvas.drawRect(
        forecastRect,
        Paint()
          ..color = forecastAreaColor.withOpacity(0.75)
          ..style = PaintingStyle.fill,
      );

      _drawText(
        canvas: canvas,
        text: 'Forecast 7 Hari',
        offset: Offset(forecastStartX + 6, chartRect.top + 8),
        color: predictionColor.withOpacity(0.85),
        fontSize: 9,
        maxWidth: 100,
        textAlign: TextAlign.left,
      );
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

    final predictionOffsets = <Offset>[];

    for (int i = 0; i < predictionPoints.length; i++) {
      final allIndex = actualPoints.length + i;

      predictionOffsets.add(
        Offset(
          getX(allIndex),
          getY(predictionPoints[i].value),
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

    if (predictionOffsets.isNotEmpty) {
      final predictionPath = Path();

      if (actualOffsets.isNotEmpty) {
        predictionPath.moveTo(
          actualOffsets.last.dx,
          actualOffsets.last.dy,
        );
      } else {
        predictionPath.moveTo(
          predictionOffsets.first.dx,
          predictionOffsets.first.dy,
        );
      }

      for (final offset in predictionOffsets) {
        predictionPath.lineTo(offset.dx, offset.dy);
      }

      canvas.drawPath(predictionPath, predictionPaint);
    }

    for (int i = 0; i < actualOffsets.length; i++) {
      final offset = actualOffsets[i];

      canvas.drawCircle(offset, 6, actualHaloPaint);
      canvas.drawCircle(offset, 3.8, actualPointPaint);

      _drawText(
        canvas: canvas,
        text: actualPoints[i].value.round().toString(),
        offset: Offset(offset.dx - 15, offset.dy - 22),
        color: actualColor,
        fontSize: 9,
        maxWidth: 30,
        textAlign: TextAlign.center,
      );
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
    }

    for (int i = 0; i < allPoints.length; i++) {
      final offset = Offset(getX(i), chartRect.bottom);

      _drawText(
        canvas: canvas,
        text: allPoints[i].label,
        offset: Offset(offset.dx - 15, chartRect.bottom + 10),
        color: textColor,
        fontSize: 8,
        maxWidth: 30,
        textAlign: TextAlign.center,
      );
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
        oldDelegate.predictionPoints != predictionPoints ||
        oldDelegate.regressionResult != regressionResult ||
        oldDelegate.actualColor != actualColor ||
        oldDelegate.trendColor != trendColor ||
        oldDelegate.predictionColor != predictionColor ||
        oldDelegate.forecastAreaColor != forecastAreaColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor;
  }
}
