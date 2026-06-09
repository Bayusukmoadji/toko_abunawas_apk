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

  Widget _buildProductFilter() {
    if (_products.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
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
        const Text(
          'Pilih Produk',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/batch/cardsum.png'),
              fit: BoxFit.fill,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedProductId,
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
            decoration: const InputDecoration(
              labelText: 'Produk / Merk Beras',
              labelStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 14,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.black26),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.green),
              ),
            ),
            items: _products.map((product) {
              return DropdownMenuItem<String>(
                value: product.id,
                child: Text(
                  product.name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
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
      return Container(); // Sembunyikan jika tidak ada produk
    }

    if (dailyData.length < 3 || result == null) {
      return _buildNotEnoughDataCard(dailyData.length);
    }

    final trendColor = _getTrendColor(result.slope);
    final trendLabel = _getTrendLabel(result.slope);
    final trendIcon = _getTrendIcon(result.slope);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hasil Analisis',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/batch/cardsum.png'),
              fit: BoxFit.fill,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Status Tren
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
                        Text(
                          result.trendStatus,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(text: trendLabel, color: trendColor),
                ],
              ),
              const SizedBox(height: 16),

              // Tabel Metrik
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
                value: '${result.totalQty} karung',
              ),
              _buildResultRow(
                icon: Icons.bar_chart,
                label: 'Rata-rata per Hari',
                value: '${result.averageQty.toStringAsFixed(0)} karung',
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
                'Nilai slope menunjukan arah perubahan stok keluar. Slope positif berarti pengeluaran cenderung meningkat, slope negatif berarti menurun, sedangkan nilai mendekati 0 menunjukan tren relatif stabil. Hasil analisis ini bersifat pendukung dan bukan keputusan otomatis.',
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

  Widget _buildNotEnoughDataCard(int dailyDataCount) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
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
                  'Produk ${_getSelectedProductName()} baru memiliki $dailyDataCount hari data stok keluar. Minimal diperlukan 3 hari data transaksi stok keluar untuk melakukan analisis tren.',
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
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
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
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data Harian Stok Keluar',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Data harian diambil dari transaksi stok keluar berdasarkan produk yang dipilih.',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 11,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...dailyData.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            constraints: const BoxConstraints(minHeight: 70),
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/batch/cardbatch.png'),
                fit: BoxFit.fill,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      mainAxisAlignment: MainAxisAlignment.center,
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
                          'Stok Keluar: ${item.qty} karung',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
            borderRadius: BorderRadius.circular(12),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_double_arrow_left,
                color: Colors.white),
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
      ),
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
                        horizontal: 16, vertical: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                          horizontal: 16, vertical: 20),
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
                          _buildDailyDataList(dailyData),
                        ],
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
