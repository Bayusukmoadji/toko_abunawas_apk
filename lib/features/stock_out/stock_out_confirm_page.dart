import 'package:flutter/material.dart';

import '../../data/models/app_user_model.dart';
import '../../data/models/batch_model.dart';
import '../../data/repositories/batch_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/transaction_repository.dart';

class StockOutConfirmPage extends StatefulWidget {
  final AppUserModel user;
  final BatchModel scannedBatch;

  const StockOutConfirmPage({
    super.key,
    required this.user,
    required this.scannedBatch,
  });

  @override
  State<StockOutConfirmPage> createState() => _StockOutConfirmPageState();
}

class _StockOutConfirmPageState extends State<StockOutConfirmPage> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _notesController = TextEditingController();

  final BatchRepository _batchRepository = BatchRepository();
  final ProductRepository _productRepository = ProductRepository();
  final TransactionRepository _transactionRepository = TransactionRepository();

  BatchModel? _fifoBatch;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isFifoValid = false;

  @override
  void initState() {
    super.initState();
    _checkFifo();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkFifo() async {
    try {
      final fifoBatch = await _batchRepository.getOldestActiveBatchByProductId(
        widget.scannedBatch.productId,
      );

      if (!mounted) return;

      setState(() {
        _fifoBatch = fifoBatch;
        _isFifoValid =
            fifoBatch != null && fifoBatch.id == widget.scannedBatch.id;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal validasi FIFO: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveStockOut() async {
    if (!_isFifoValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Batch ini tidak sesuai urutan FIFO.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final qty = int.parse(_qtyController.text.trim());

      await _batchRepository.decreaseBatchStock(
        batchId: widget.scannedBatch.id,
        qty: qty,
      );

      await _productRepository.decreaseTotalStock(
        productId: widget.scannedBatch.productId,
        qty: qty,
      );

      await _transactionRepository.createStockOutTransaction(
        productId: widget.scannedBatch.productId,
        productName: widget.scannedBatch.productName,
        batchId: widget.scannedBatch.id,
        batchCode: widget.scannedBatch.batchCode,
        qty: qty,
        unit: widget.scannedBatch.unit,
        performedBy: widget.user.uid,
        performedByName: widget.user.name,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stok keluar berhasil disimpan.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan stok keluar: $e'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() {
        _isSubmitting = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
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
                Icons.outbox_outlined,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Konfirmasi Stok Keluar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Periksa validasi FIFO dan isi jumlah stok yang akan dikeluarkan dari batch.',
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

  Widget _buildFifoStatusCard() {
    final color = _isFifoValid ? Colors.green : Colors.red;
    final icon =
        _isFifoValid ? Icons.check_circle_outline : Icons.error_outline;
    final title = _isFifoValid ? 'FIFO Sesuai' : 'FIFO Tidak Sesuai';
    final message = _isFifoValid
        ? 'Batch ini adalah batch aktif paling lama untuk produk terkait. Stok keluar dapat diproses.'
        : 'Batch yang dipindai bukan batch aktif paling lama. Sistem menolak stok keluar agar aturan FIFO tetap berjalan.';

    return Card(
      color: color.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    message,
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

  Widget _buildInfoRow({
    required String label,
    required String value,
  }) {
    final displayValue = value.trim().isEmpty ? '-' : value.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard({
    required String title,
    required BatchModel batch,
    required Color color,
    required IconData icon,
  }) {
    final receivedDate = batch.receivedAt.toDate();
    final location =
        batch.storageLocation.trim().isEmpty ? '-' : batch.storageLocation;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(
                    icon,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildInfoRow(
              label: 'Produk',
              value: batch.productName,
            ),
            _buildInfoRow(
              label: 'Kode Batch',
              value: batch.batchCode,
            ),
            _buildInfoRow(
              label: 'Lokasi',
              value: location,
            ),
            _buildInfoRow(
              label: 'Tanggal Masuk',
              value: _formatDate(receivedDate),
            ),
            _buildInfoRow(
              label: 'Sisa Stok',
              value: '${batch.remainingQty} ${batch.unit}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockOutForm(BatchModel scannedBatch) {
    return Form(
      key: _formKey,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Form Stok Keluar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isFifoValid
                    ? 'Masukkan jumlah stok yang keluar dari batch ini.'
                    : 'Form dinonaktifkan karena batch tidak sesuai aturan FIFO.',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _qtyController,
                enabled: _isFifoValid,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Jumlah Stok Keluar',
                  hintText: 'Contoh: 1',
                  prefixIcon: const Icon(Icons.numbers),
                  suffixText: scannedBatch.unit,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Jumlah tidak boleh kosong';
                  }

                  final qty = int.tryParse(value.trim());

                  if (qty == null || qty <= 0) {
                    return 'Jumlah harus berupa angka lebih dari 0';
                  }

                  if (qty > scannedBatch.remainingQty) {
                    return 'Jumlah keluar melebihi sisa stok batch';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                enabled: _isFifoValid,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Catatan',
                  hintText: 'Opsional',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed:
                      !_isFifoValid || _isSubmitting ? null : _saveStockOut,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSubmitting ? 'Menyimpan...' : 'Simpan Stok Keluar',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konfirmasi Stok Keluar'),
      ),
      body: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text(
                  'Memeriksa aturan FIFO...',
                  style: TextStyle(
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

  @override
  Widget build(BuildContext context) {
    final scannedBatch = widget.scannedBatch;

    if (_isLoading) {
      return _buildLoadingPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konfirmasi Stok Keluar'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 12),
                  _buildFifoStatusCard(),
                  const SizedBox(height: 12),
                  _buildBatchCard(
                    title: 'Batch yang Dipindai',
                    batch: scannedBatch,
                    color: _isFifoValid ? Colors.green : Colors.red,
                    icon: Icons.qr_code_2,
                  ),
                  if (!_isFifoValid && _fifoBatch != null) ...[
                    const SizedBox(height: 12),
                    _buildBatchCard(
                      title: 'Batch yang Seharusnya Keluar',
                      batch: _fifoBatch!,
                      color: Colors.orange,
                      icon: Icons.priority_high_outlined,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildStockOutForm(scannedBatch),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
