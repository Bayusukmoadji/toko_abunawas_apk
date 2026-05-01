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
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scannedBatch = widget.scannedBatch;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final scannedDate = scannedBatch.receivedAt.toDate();
    final fifoDate = _fifoBatch?.receivedAt.toDate();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konfirmasi Stok Keluar'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color:
                      _isFifoValid ? Colors.green.shade50 : Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _isFifoValid
                          ? 'Validasi FIFO sesuai. Batch ini boleh dikeluarkan.'
                          : 'Peringatan FIFO: batch ini bukan batch paling lama. Ambil batch yang lebih dahulu masuk.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isFifoValid ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Batch yang Dipindai',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('Produk', scannedBatch.productName),
                        _buildInfoRow('Kode Batch', scannedBatch.batchCode),
                        _buildInfoRow(
                          'Lokasi',
                          scannedBatch.storageLocation.isEmpty
                              ? '-'
                              : scannedBatch.storageLocation,
                        ),
                        _buildInfoRow(
                          'Tanggal Masuk',
                          _formatDate(scannedDate),
                        ),
                        _buildInfoRow(
                          'Sisa Stok',
                          '${scannedBatch.remainingQty} ${scannedBatch.unit}',
                        ),
                      ],
                    ),
                  ),
                ),
                if (!_isFifoValid && _fifoBatch != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Batch yang Seharusnya Keluar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Produk', _fifoBatch!.productName),
                          _buildInfoRow('Kode Batch', _fifoBatch!.batchCode),
                          _buildInfoRow(
                            'Lokasi',
                            _fifoBatch!.storageLocation.isEmpty
                                ? '-'
                                : _fifoBatch!.storageLocation,
                          ),
                          _buildInfoRow(
                            'Tanggal Masuk',
                            fifoDate == null ? '-' : _formatDate(fifoDate),
                          ),
                          _buildInfoRow(
                            'Sisa Stok',
                            '${_fifoBatch!.remainingQty} ${_fifoBatch!.unit}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _qtyController,
                            enabled: _isFifoValid,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Jumlah Stok Keluar',
                              hintText: 'Contoh: 1',
                              border: OutlineInputBorder(),
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
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: !_isFifoValid || _isSubmitting
                                  ? null
                                  : _saveStockOut,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Simpan Stok Keluar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
