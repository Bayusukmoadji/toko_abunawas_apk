import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/app_user_model.dart';
import '../../data/models/batch_model.dart';
import '../../data/repositories/batch_repository.dart';
import '../../data/repositories/stock_out_repository.dart';

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

  final StockOutRepository _stockOutRepository = StockOutRepository();

  BatchModel? _fifoBatch;

  bool _isLoading = true;
  bool _isPreparingPreview = false;
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

  String _errorText(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  void _showFloatingSnackBar(
    String message,
    Color color,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.only(
          bottom: 24,
          left: 16,
          right: 16,
        ),
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
        'Gagal validasi FIFO: ${_errorText(e)}',
        Colors.redAccent,
      );
    }
  }

  Future<void> _previewAndSaveStockOut() async {
    if (!_isFifoValid) {
      _showFloatingSnackBar(
        'Batch ini tidak sesuai urutan FIFO.',
        Colors.redAccent,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final qty = int.tryParse(
      _qtyController.text.trim(),
    );

    if (qty == null || qty <= 0) {
      _showFloatingSnackBar(
        'Jumlah stok keluar harus berupa angka lebih dari 0.',
        Colors.redAccent,
      );
      return;
    }

    setState(() {
      _isPreparingPreview = true;
    });

    try {
      final preview = await _stockOutRepository.previewStockOut(
        batchId: widget.scannedBatch.id,
        qty: qty,
      );

      if (!mounted) return;

      setState(() {
        _isPreparingPreview = false;
      });

      final confirmed = await _showAllocationPreviewDialog(
        preview,
      );

      if (confirmed != true || !mounted) {
        return;
      }

      await _saveStockOut(qty);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isPreparingPreview = false;
      });

      _showFloatingSnackBar(
        _errorText(e),
        Colors.redAccent,
      );
    }
  }

  Future<void> _saveStockOut(int qty) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _stockOutRepository.processStockOut(
        batchId: widget.scannedBatch.id,
        qty: qty,
        performedBy: widget.user.uid,
        performedByName: widget.user.name,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      await _showSuccessDialog(result);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      _showFloatingSnackBar(
        'Gagal menyimpan stok keluar: ${_errorText(e)}',
        Colors.redAccent,
      );

      // Setelah kegagalan, periksa ulang FIFO
      // karena data mungkin berubah akibat transaksi lain.
      await _checkFifo();
    }
  }

  Future<bool?> _showAllocationPreviewDialog(
    Map<String, dynamic> preview,
  ) {
    final allocations = (preview['allocations'] as List<dynamic>? ?? [])
        .map(
          (item) => Map<String, dynamic>.from(
            item as Map,
          ),
        )
        .toList();

    final isCrossBatch = preview['isCrossBatch'] == true;

    final requestedQty = preview['requestedQty'] ?? 0;

    final totalActiveStock = preview['totalActiveStock'] ?? 0;

    final totalStockAfter = preview['totalStockAfter'] ?? 0;

    final unit = (preview['unit'] ?? '').toString();

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            0,
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            8,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16,
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: isCrossBatch
                      ? Colors.orange.shade50
                      : const Color(0xFFF1F8F1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCrossBatch
                      ? Icons.call_split_rounded
                      : Icons.inventory_2_outlined,
                  color: isCrossBatch
                      ? Colors.orange.shade800
                      : const Color(0xFF038E1B),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Pratinjau Stok Keluar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCrossBatch
                          ? Colors.orange.shade50
                          : const Color(0xFFF1F8F1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCrossBatch
                            ? Colors.orange.shade200
                            : const Color(
                                0xFFB7DEB7,
                              ),
                      ),
                    ),
                    child: Text(
                      isCrossBatch
                          ? 'Jumlah yang diminta melebihi sisa batch pertama. '
                              'Sistem akan menghabiskan batch tertua dan '
                              'melanjutkan pengeluaran ke batch berikutnya '
                              'secara otomatis sesuai FIFO.'
                          : 'Jumlah dapat dipenuhi seluruhnya oleh batch '
                              'prioritas FIFO pertama.',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPreviewSummaryRow(
                    'Jumlah diminta',
                    '$requestedQty $unit',
                  ),
                  _buildPreviewSummaryRow(
                    'Total stok aktif',
                    '$totalActiveStock $unit',
                  ),
                  _buildPreviewSummaryRow(
                    'Sisa total setelah transaksi',
                    '$totalStockAfter $unit',
                  ),
                  _buildPreviewSummaryRow(
                    'Batch yang digunakan',
                    '${allocations.length} batch',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pembagian FIFO',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(
                    allocations.length,
                    (index) {
                      final item = allocations[index];

                      final batchCode = (item['batchCode'] ?? '-').toString();

                      final date = (item['receivedAt'] ?? '-').toString();

                      final location =
                          (item['storageLocation'] ?? '-').toString();

                      final before = item['remainingQtyBefore'] ?? 0;

                      final allocated = item['allocatedQty'] ?? 0;

                      final after = item['remainingQtyAfter'] ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(
                          bottom: 10,
                        ),
                        padding: const EdgeInsets.all(
                          14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(
                            12,
                          ),
                          border: Border.all(
                            color: Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 15,
                                  backgroundColor: const Color(
                                    0xFF038E1B,
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Expanded(
                                  child: Text(
                                    batchCode,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Tanggal masuk: $date',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              'Lokasi: $location',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$before $unit → '
                              'keluar $allocated $unit → '
                              'sisa $after $unit',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Batal'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(
                Icons.check_rounded,
                color: Colors.white,
              ),
              label: const Text(
                'Konfirmasi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF038E1B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewSummaryRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccessDialog(
    Map<String, dynamic> result,
  ) {
    final batchCount = result['batchCount'] ?? 1;

    final qty = result['requestedQty'] ?? result['qty'] ?? 0;

    final unit = (result['unit'] ?? '').toString();

    final totalStockAfter = result['totalStockAfter'] ?? 0;

    final groupId = (result['transactionGroupId'] ?? '-').toString();

    final isCrossBatch = result['isCrossBatch'] == true;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF038E1B),
                size: 30,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Stok Keluar Berhasil',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            isCrossBatch
                ? '$qty $unit berhasil dikeluarkan menggunakan '
                    '$batchCount batch sesuai urutan FIFO.\n\n'
                    'Sisa total stok produk: '
                    '$totalStockAfter $unit.\n'
                    'ID kelompok transaksi: $groupId.'
                : '$qty $unit berhasil dikeluarkan dari '
                    'batch prioritas FIFO.\n\n'
                    'Sisa total stok produk: '
                    '$totalStockAfter $unit.\n'
                    'ID kelompok transaksi: $groupId.',
            style: const TextStyle(
              height: 1.5,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF038E1B),
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
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
          colors: [
            Color(0xFF015816),
            Color(0xFF038E1B),
          ],
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
                  'Pindai batch prioritas FIFO satu kali. '
                  'Jika jumlah pengeluaran melebihi sisa batch '
                  'pertama, sistem akan mengalokasikan kekurangannya '
                  'ke batch berikutnya secara otomatis.',
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
        ? 'Batch yang dipindai adalah batch aktif paling lama. '
            'Stok keluar dapat diproses dan sistem dapat melanjutkan '
            'otomatis ke batch berikutnya apabila diperlukan.'
        : 'Batch yang dipindai bukan batch aktif paling lama. '
            'Transaksi ditolak agar urutan FIFO tetap terjaga.';

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [_figmaShadow],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 28,
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
            ': ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
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

    final location = batch.storageLocation.trim().isEmpty
        ? '-'
        : batch.storageLocation.trim();

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
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
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
            label: 'Sisa Batch Ini',
            value: '${batch.remainingQty} ${batch.unit}',
          ),
        ],
      ),
    );
  }

  Widget _buildStockOutForm(
    BatchModel scannedBatch,
  ) {
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
                  ? 'Masukkan jumlah total yang akan dikeluarkan. '
                      'Jumlah tidak lagi dibatasi oleh sisa batch '
                      'pertama karena sistem dapat melakukan alokasi '
                      'lintas-batch secara otomatis.'
                  : 'Form dinonaktifkan karena batch '
                      'tidak sesuai aturan FIFO.',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _qtyController,
              enabled: _isFifoValid && !_isSubmitting && !_isPreparingPreview,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              textInputAction: TextInputAction.next,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: 'Jumlah Total Stok Keluar',
                hintText: 'Contoh: 25',
                helperText: 'Jika melebihi ${scannedBatch.remainingQty} '
                    '${scannedBatch.unit} pada batch pertama, '
                    'sistem otomatis menggunakan batch berikutnya.',
                helperMaxLines: 3,
                labelStyle: TextStyle(
                  color: _isFifoValid
                      ? const Color(
                          0xFF038E1B,
                        )
                      : Colors.grey,
                ),
                prefixIcon: Icon(
                  Icons.numbers,
                  color: _isFifoValid
                      ? const Color(
                          0xFF038E1B,
                        )
                      : Colors.grey,
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
                    color: const Color(
                      0xFF038E1B,
                    ).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF038E1B),
                    width: 2,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.grey.shade300,
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
                    width: 2,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Jumlah tidak boleh kosong';
                }

                final qty = int.tryParse(
                  value.trim(),
                );

                if (qty == null || qty <= 0) {
                  return 'Jumlah harus berupa angka lebih dari 0';
                }

                // PENTING:
                // TIDAK ADA lagi validasi:
                //
                // qty > scannedBatch.remainingQty
                //
                // karena jumlah boleh dilanjutkan ke
                // batch FIFO berikutnya.
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              enabled: _isFifoValid && !_isSubmitting && !_isPreparingPreview,
              maxLines: 3,
              style: const TextStyle(
                fontSize: 14,
              ),
              decoration: InputDecoration(
                labelText: 'Catatan (Opsional)',
                hintText: 'Tambahkan keterangan jika perlu...',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(
                    bottom: 44,
                  ),
                  child: Icon(
                    Icons.notes_outlined,
                    color: _isFifoValid
                        ? const Color(
                            0xFF038E1B,
                          )
                        : Colors.grey,
                  ),
                ),
                filled: true,
                fillColor: _isFifoValid ? Colors.white : Colors.grey.shade100,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: const Color(
                      0xFF038E1B,
                    ).withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF038E1B),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: !_isFifoValid || _isSubmitting || _isPreparingPreview
                    ? null
                    : _previewAndSaveStockOut,
                icon: _isSubmitting || _isPreparingPreview
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.fact_check_outlined,
                        color: Colors.white,
                      ),
                label: Text(
                  _isSubmitting
                      ? 'Menyimpan...'
                      : _isPreparingPreview
                          ? 'Menyiapkan alokasi...'
                          : 'Tinjau & Simpan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF038E1B),
                  disabledBackgroundColor: Colors.grey.shade400,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      14,
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
                    onTap: _isSubmitting
                        ? null
                        : () => Navigator.pop(
                              context,
                            ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 560,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(
                        height: 20,
                      ),
                      _buildFifoStatusCard(),
                      const SizedBox(
                        height: 20,
                      ),
                      _buildBatchCard(
                        title: 'Batch yang Dipindai',
                        batch: scannedBatch,
                        color: _isFifoValid
                            ? const Color(
                                0xFF038E1B,
                              )
                            : Colors.redAccent,
                        icon: Icons.qr_code_scanner_rounded,
                      ),
                      if (!_isFifoValid && _fifoBatch != null) ...[
                        const SizedBox(
                          height: 20,
                        ),
                        _buildBatchCard(
                          title: 'Batch yang Seharusnya Keluar',
                          batch: _fifoBatch!,
                          color: Colors.orange.shade800,
                          icon: Icons.priority_high_rounded,
                        ),
                      ],
                      const SizedBox(
                        height: 20,
                      ),
                      _buildStockOutForm(
                        scannedBatch,
                      ),
                      const SizedBox(
                        height: 32,
                      ),
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
