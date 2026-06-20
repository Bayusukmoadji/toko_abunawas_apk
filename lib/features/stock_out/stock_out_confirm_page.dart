import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  final BoxShadow _figmaShadow = BoxShadow(
    color: Colors.black.withOpacity(0.15),
    offset: const Offset(0, 4),
    blurRadius: 12,
    spreadRadius: 0,
  );

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

  void _showFloatingSnackBar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      ),
    );
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

      _showFloatingSnackBar(
        'Gagal validasi FIFO: $e',
        Colors.redAccent,
      );
    }
  }

  Future<void> _saveStockOut() async {
    if (!_isFifoValid) {
      _showFloatingSnackBar(
        'Batch ini tidak sesuai urutan FIFO.',
        Colors.redAccent,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final qty = int.tryParse(_qtyController.text.trim());

    if (qty == null || qty <= 0) {
      _showFloatingSnackBar(
        'Jumlah stok keluar harus berupa angka lebih dari 0.',
        Colors.redAccent,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
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

      await _productRepository.syncTotalStockFromBatches(
        productId: widget.scannedBatch.productId,
      );

      if (!mounted) return;

      _showFloatingSnackBar(
        'Stok keluar berhasil disimpan.',
        const Color(0xFF038E1B),
      );

      Navigator.pop(context);
    } catch (e) {
      try {
        await _productRepository.syncTotalStockFromBatches(
          productId: widget.scannedBatch.productId,
        );
      } catch (_) {
        // Sinkronisasi cadangan gagal, pesan utama tetap ditampilkan.
      }

      if (!mounted) return;

      _showFloatingSnackBar(
        'Gagal menyimpan stok keluar: $e',
        Colors.redAccent,
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
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF015816), Color(0xFF038E1B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [_figmaShadow],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.outbox_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Konfirmasi Stok',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Periksa validasi FIFO dan isi jumlah stok yang akan dikeluarkan dari batch ini.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFifoStatusCard() {
    final color = _isFifoValid ? const Color(0xFF038E1B) : Colors.redAccent;
    final bgColor =
        _isFifoValid ? const Color(0xFFF1F8F1) : const Color(0xFFFEF2F2);
    final icon =
        _isFifoValid ? Icons.check_circle_outline : Icons.error_outline;
    final title = _isFifoValid ? 'FIFO Sesuai' : 'FIFO Tidak Sesuai';
    final message = _isFifoValid
        ? 'Batch ini adalah batch aktif paling lama. Stok keluar dapat diproses.'
        : 'Batch yang dipindai bukan batch aktif paling lama. Sistem menolak stok keluar agar aturan FIFO tetap berjalan.';

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [_figmaShadow],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
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
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
  }) {
    final displayValue = value.trim().isEmpty ? '-' : value.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Text(
            ':  ',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [_figmaShadow],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow(label: 'Produk', value: batch.productName),
          _buildInfoRow(label: 'Kode Batch', value: batch.batchCode),
          _buildInfoRow(label: 'Lokasi', value: location),
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
    );
  }

  Widget _buildStockOutForm(BatchModel scannedBatch) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [_figmaShadow],
      ),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Form Pengeluaran',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isFifoValid
                  ? 'Masukkan jumlah stok yang keluar dari batch ini.'
                  : 'Form dinonaktifkan karena batch tidak sesuai aturan.',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _qtyController,
              enabled: _isFifoValid,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Jumlah Stok Keluar',
                hintText: 'Contoh: 1',
                labelStyle: TextStyle(
                  color: _isFifoValid ? const Color(0xFF038E1B) : Colors.grey,
                ),
                prefixIcon: Icon(
                  Icons.numbers,
                  color: _isFifoValid ? const Color(0xFF038E1B) : Colors.grey,
                ),
                suffixText: scannedBatch.unit,
                suffixStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
                filled: true,
                fillColor: _isFifoValid ? Colors.white : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: const Color(0xFF038E1B).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF038E1B),
                    width: 2.0,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.grey.shade300,
                    width: 1.0,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Colors.redAccent,
                    width: 1.5,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Colors.redAccent,
                    width: 2.0,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Jumlah tidak boleh kosong';
                }

                final qty = int.tryParse(value.trim());

                if (qty == null || qty <= 0) {
                  return 'Harus berupa angka > 0';
                }

                if (qty > scannedBatch.remainingQty) {
                  return 'Melebihi sisa stok (Maks: ${scannedBatch.remainingQty})';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              enabled: _isFifoValid,
              maxLines: 3,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Catatan (Opsional)',
                hintText: 'Tambahkan keterangan jika perlu...',
                labelStyle: TextStyle(
                  color: _isFifoValid ? const Color(0xFF038E1B) : Colors.grey,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 44.0),
                  child: Icon(
                    Icons.notes_outlined,
                    color: _isFifoValid ? const Color(0xFF038E1B) : Colors.grey,
                  ),
                ),
                alignLabelWithHint: true,
                filled: true,
                fillColor: _isFifoValid ? Colors.white : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: const Color(0xFF038E1B).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF038E1B),
                    width: 2.0,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.grey.shade300,
                    width: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.center,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isFifoValid
                        ? [const Color(0xFF015816), const Color(0xFF038E1B)]
                        : [Colors.grey.shade400, Colors.grey.shade500],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _isFifoValid && !_isSubmitting
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: const Offset(0, 4),
                            blurRadius: 10,
                          ),
                        ]
                      : [],
                ),
                child: ElevatedButton.icon(
                  onPressed:
                      !_isFifoValid || _isSubmitting ? null : _saveStockOut,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: 22,
                        ),
                  label: Text(
                    _isSubmitting ? 'Menyimpan...' : 'Simpan Stok Keluar',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [_figmaShadow],
              ),
              child: const CircularProgressIndicator(
                color: Color(0xFF038E1B),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Memeriksa Aturan FIFO...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF015816),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mohon tunggu sebentar',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
          ],
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
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 24,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF015816),
                  Color(0xFF038E1B),
                  Color(0xFF84E977),
                ],
                stops: [0.0, 0.5, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [_figmaShadow],
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.keyboard_double_arrow_left,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Detail Stok Keluar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 20),
                      _buildFifoStatusCard(),
                      const SizedBox(height: 20),
                      _buildBatchCard(
                        title: 'Batch yang Dipindai',
                        batch: scannedBatch,
                        color: _isFifoValid
                            ? const Color(0xFF038E1B)
                            : Colors.redAccent,
                        icon: Icons.qr_code_scanner_rounded,
                      ),
                      if (!_isFifoValid && _fifoBatch != null) ...[
                        const SizedBox(height: 20),
                        _buildBatchCard(
                          title: 'Batch yang Seharusnya Keluar',
                          batch: _fifoBatch!,
                          color: Colors.orange.shade800,
                          icon: Icons.priority_high_rounded,
                        ),
                      ],
                      const SizedBox(height: 20),
                      _buildStockOutForm(scannedBatch),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
