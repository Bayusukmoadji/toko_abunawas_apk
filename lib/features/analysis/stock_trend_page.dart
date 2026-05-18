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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  String _getSelectedProductName() {
    if (_selectedProductId == null) {
      return '-';
    }

    final matchedProducts = _products.where(
      (product) => product.id == _selectedProductId,
    );

    if (matchedProducts.isEmpty) {
      return '-';
    }

    return matchedProducts.first.name;
  }

  List<_DailyStockOut> _buildDailyStockOutData(
    List<TransactionModel> transactions,
  ) {
    final Map<String, _DailyStockOut> dailyMap = {};

    final stockOutTransactions = transactions.where((transaction) {
      return transaction.type == 'stock_out' &&
          transaction.productId == _selectedProductId;
    }).toList();

    for (final transaction in stockOutTransactions) {
      final dateTime = transaction.createdAt.toDate();

      final dateOnly = DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day,
      );

      final key = '${dateOnly.year}-${dateOnly.month}-${dateOnly.day}';

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

    double estimatedNext7Days = 0;

    for (int i = n; i < n + 7; i++) {
      final prediction = intercept + (slope * i);
      estimatedNext7Days += prediction < 0 ? 0 : prediction;
    }

    String trendStatus;

    if (slope > 0.1) {
      trendStatus = 'Pengeluaran stok cenderung meningkat.';
    } else if (slope < -0.1) {
      trendStatus = 'Pengeluaran stok cenderung menurun.';
    } else {
      trendStatus = 'Pengeluaran stok relatif stabil.';
    }

    final totalQty = data.fold<int>(
      0,
      (total, item) => total + item.qty,
    );

    final averageQty = totalQty / data.length;

    return _RegressionResult(
      slope: slope,
      intercept: intercept,
      trendStatus: trendStatus,
      totalQty: totalQty,
      averageQty: averageQty,
      estimatedNext7Days: estimatedNext7Days,
    );
  }

  String _getTrendLabel(double slope) {
    if (slope > 0.1) {
      return 'Meningkat';
    }

    if (slope < -0.1) {
      return 'Menurun';
    }

    return 'Stabil';
  }

  Color _getTrendColor(double slope) {
    if (slope > 0.1) {
      return Colors.red;
    }

    if (slope < -0.1) {
      return Colors.blue;
    }

    return Colors.green;
  }

  IconData _getTrendIcon(double slope) {
    if (slope > 0.1) {
      return Icons.trending_up;
    }

    if (slope < -0.1) {
      return Icons.trending_down;
    }

    return Icons.trending_flat;
  }

  Widget _buildHeaderCard() {
    return const Card(
      color: Color(0xFF2E7D32),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(
                Icons.trending_up,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analisis Tren Stok',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Analisis pola stok keluar per produk menggunakan pendekatan linear regression sederhana.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductFilter() {
    if (_products.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: Colors.grey,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Belum ada produk aktif untuk dianalisis.',
                  style: TextStyle(
                    color: Colors.black87,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pilih Produk',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Analisis dilakukan per produk/merk agar pola pengeluaran stok lebih spesifik.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedProductId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Produk / Merk Beras',
                prefixIcon: Icon(Icons.rice_bowl_outlined),
              ),
              items: _products.map((product) {
                return DropdownMenuItem<String>(
                  value: product.id,
                  child: Text(
                    product.name,
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
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisResult({
    required List<_DailyStockOut> dailyData,
    required _RegressionResult? result,
  }) {
    if (_selectedProductId == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.orange,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Silakan pilih produk terlebih dahulu.',
                  style: TextStyle(
                    color: Colors.black87,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (dailyData.length < 3 || result == null) {
      return _buildNotEnoughDataCard(dailyData.length);
    }

    final trendColor = _getTrendColor(result.slope);
    final trendLabel = _getTrendLabel(result.slope);
    final trendIcon = _getTrendIcon(result.slope);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: trendColor.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: trendColor.withOpacity(0.14),
                  child: Icon(
                    trendIcon,
                    color: trendColor,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status Tren',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildStatusChip(
                        text: trendLabel,
                        color: trendColor,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        result.trendStatus,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hasil Analisis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildResultRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Produk',
                  value: _getSelectedProductName(),
                  color: Colors.blue,
                ),
                _buildResultRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'Jumlah Data Harian',
                  value: '${dailyData.length} hari',
                  color: Colors.teal,
                ),
                _buildResultRow(
                  icon: Icons.arrow_upward,
                  label: 'Total Stok Keluar',
                  value: '${result.totalQty} karung',
                  color: Colors.red,
                ),
                _buildResultRow(
                  icon: Icons.bar_chart,
                  label: 'Rata-rata per Hari',
                  value: '${result.averageQty.toStringAsFixed(2)} karung',
                  color: Colors.orange,
                ),
                _buildResultRow(
                  icon: Icons.functions,
                  label: 'Nilai Slope',
                  value: result.slope.toStringAsFixed(3),
                  color: trendColor,
                ),
                _buildResultRow(
                  icon: Icons.calculate_outlined,
                  label: 'Nilai Intercept',
                  value: result.intercept.toStringAsFixed(3),
                  color: Colors.deepPurple,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFFE8F5E9),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.event_available_outlined,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimasi Kebutuhan 7 Hari',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${result.estimatedNext7Days.toStringAsFixed(0)} karung',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Estimasi dihitung berdasarkan pola stok keluar historis produk yang dipilih.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.black54,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildExplanationCard(),
      ],
    );
  }

  Widget _buildNotEnoughDataCard(int dailyDataCount) {
    return Card(
      color: Colors.orange.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.14),
              child: const Icon(
                Icons.info_outline,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Data Belum Cukup',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Produk ${_getSelectedProductName()} baru memiliki $dailyDataCount hari data stok keluar. Minimal diperlukan 3 hari data transaksi stok keluar untuk melakukan analisis tren.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationCard() {
    return Card(
      color: Colors.blue.shade50,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.help_outline,
              color: Colors.blue,
              size: 22,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nilai slope menunjukkan arah perubahan stok keluar. Slope positif berarti pengeluaran cenderung meningkat, slope negatif berarti menurun, sedangkan nilai mendekati 0 menunjukkan tren relatif stabil. Hasil analisis ini bersifat pendukung dan bukan keputusan otomatis.',
                style: TextStyle(
                  fontSize: 12.8,
                  color: Colors.black87,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                color: color,
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
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.35),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDailyDataList(List<_DailyStockOut> dailyData) {
    if (dailyData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.receipt_long,
                color: Colors.grey,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Belum ada transaksi stok keluar untuk produk yang dipilih.',
                  style: TextStyle(
                    color: Colors.black87,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: dailyData.map((item) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.12),
                  child: const Icon(
                    Icons.calendar_today,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(item.date),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Stok keluar: ${item.qty} karung',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data Harian Stok Keluar',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Data harian diambil dari transaksi stok keluar berdasarkan produk yang dipilih.',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Gagal memuat transaksi: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProducts) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Analisis Tren Stok'),
        ),
        body: _buildLoadingState(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analisis Tren Stok'),
      ),
      body: StreamBuilder<List<TransactionModel>>(
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
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 12),
                      _buildProductFilter(),
                      const SizedBox(height: 12),
                      _buildAnalysisResult(
                        dailyData: dailyData,
                        result: regressionResult,
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle(),
                      const SizedBox(height: 12),
                      _buildDailyDataList(dailyData),
                      const SizedBox(height: 12),
                    ],
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

class _RegressionResult {
  final double slope;
  final double intercept;
  final String trendStatus;
  final int totalQty;
  final double averageQty;
  final double estimatedNext7Days;

  _RegressionResult({
    required this.slope,
    required this.intercept,
    required this.trendStatus,
    required this.totalQty,
    required this.averageQty,
    required this.estimatedNext7Days,
  });
}
// linear regression