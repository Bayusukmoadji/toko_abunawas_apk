import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/models/app_user_model.dart';
import '../../data/models/batch_condition_check_model.dart';
import '../../data/models/batch_model.dart';
import '../../data/repositories/batch_condition_repository.dart';
import '../../data/repositories/batch_repository.dart';

class BatchConditionCheckPage extends StatefulWidget {
  final AppUserModel user;
  final BatchModel? initialBatch;

  const BatchConditionCheckPage({
    super.key,
    required this.user,
    this.initialBatch,
  });

  @override
  State<BatchConditionCheckPage> createState() =>
      _BatchConditionCheckPageState();
}

class _BatchConditionCheckPageState extends State<BatchConditionCheckPage> {
  final BatchRepository _batchRepository = BatchRepository();

  final BatchConditionRepository _conditionRepository =
      BatchConditionRepository();

  final TextEditingController _notesController = TextEditingController();

  static const Color _darkGreen = Color(0xFF015816);
  static const Color _mainGreen = Color(0xFF038E1B);
  static const Color _lightGreen = Color(0xFF84E977);
  static const Color _pageBackground = Color(0xFFFAFAFA);

  static const LinearGradient _primaryGradient = LinearGradient(
    colors: [
      _darkGreen,
      _mainGreen,
      _lightGreen,
    ],
    stops: [0, 0.5, 1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  BatchModel? _selectedBatch;

  String? _packagingCondition;
  String? _odorCondition;
  String? _pestCondition;
  String? _physicalCondition;
  String? _storageCondition;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedBatch = widget.initialBatch;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  int _calculateStoredDays(DateTime receivedAt) {
    final receivedDate = DateTime(
      receivedAt.year,
      receivedAt.month,
      receivedAt.day,
    );

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final result = today.difference(receivedDate).inDays;

    return result < 0 ? 0 : result;
  }

  void _showSnackBar(
    String message,
    Color color,
  ) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  bool get _isFormComplete {
    return _packagingCondition != null &&
        _odorCondition != null &&
        _pestCondition != null &&
        _physicalCondition != null &&
        _storageCondition != null;
  }

  void _resetInspectionForm() {
    setState(() {
      _packagingCondition = null;
      _odorCondition = null;
      _pestCondition = null;
      _physicalCondition = null;
      _storageCondition = null;
    });

    _notesController.clear();
  }

  void _selectBatch(
    BatchModel batch,
  ) {
    final status = batch.status.toLowerCase().trim();

    if (status != 'active' || batch.remainingQty <= 0) {
      _showSnackBar(
        'Pemeriksaan hanya dapat dilakukan pada batch aktif '
        'yang masih memiliki stok.',
        Colors.redAccent,
      );

      return;
    }

    setState(() {
      _selectedBatch = batch;

      _packagingCondition = null;
      _odorCondition = null;
      _pestCondition = null;
      _physicalCondition = null;
      _storageCondition = null;
    });

    _notesController.clear();
  }

  Future<void> _openScanner() async {
    final batch = await Navigator.push<BatchModel>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return const _ConditionBatchScannerPage();
        },
      ),
    );

    if (!mounted || batch == null) {
      return;
    }

    _selectBatch(batch);
  }

  Future<void> _saveConditionCheck() async {
    final batch = _selectedBatch;

    if (batch == null) {
      _showSnackBar(
        'Pilih atau scan batch terlebih dahulu.',
        Colors.orange.shade800,
      );

      return;
    }

    if (!_isFormComplete) {
      _showSnackBar(
        'Lengkapi seluruh pemeriksaan kondisi terlebih dahulu.',
        Colors.orange.shade800,
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final resultStatus = BatchConditionRepository.evaluateStatus(
        packagingCondition: _packagingCondition!,
        odorCondition: _odorCondition!,
        pestCondition: _pestCondition!,
        physicalCondition: _physicalCondition!,
        storageCondition: _storageCondition!,
      );

      await _conditionRepository.saveConditionCheck(
        batch: batch,
        user: widget.user,
        packagingCondition: _packagingCondition!,
        odorCondition: _odorCondition!,
        pestCondition: _pestCondition!,
        physicalCondition: _physicalCondition!,
        storageCondition: _storageCondition!,
        notes: _notesController.text,
      );

      if (!mounted) {
        return;
      }

      final isNormal = resultStatus == BatchConditionRepository.statusNormal;

      _showSnackBar(
        isNormal
            ? 'Pemeriksaan berhasil. Kondisi batch Normal.'
            : 'Pemeriksaan berhasil. Batch ditandai Perlu Perhatian.',
        isNormal ? _mainGreen : Colors.orange.shade800,
      );

      _resetInspectionForm();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        'Gagal menyimpan pemeriksaan: $error',
        Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
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
          'PEMERIKSAAN KONDISI',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.1,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: _primaryGradient,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 11.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildInformationBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFC8E6C9),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: _mainGreen,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pemeriksaan kondisi digunakan sebagai indikator '
              'untuk menemukan batch yang perlu mendapat perhatian. '
              'Hasil pemeriksaan tidak mengubah urutan FIFO.',
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchSelector() {
    return StreamBuilder<List<BatchModel>>(
      stream: _batchRepository.getActiveBatchesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Container(
            height: 54,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _mainGreen,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildInlineError(
            'Gagal memuat daftar batch.',
          );
        }

        final batches = (snapshot.data ?? []).where(
          (batch) {
            return batch.status.toLowerCase().trim() == 'active' &&
                batch.remainingQty > 0;
          },
        ).toList();

        batches.sort(
          (first, second) {
            return first.receivedAt.compareTo(
              second.receivedAt,
            );
          },
        );

        final selectedId = _selectedBatch?.id;

        final selectedExists = selectedId != null &&
            batches.any(
              (batch) => batch.id == selectedId,
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: selectedExists ? selectedId : null,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _darkGreen,
              ),
              decoration: InputDecoration(
                labelText: 'Pilih Batch Aktif',
                labelStyle: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  Icons.inventory_2_outlined,
                  color: _darkGreen,
                  size: 20,
                ),
                filled: true,
                fillColor: const Color(0xFFF9FBF9),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFD7E7D7),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: _mainGreen,
                    width: 1.4,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: batches.map(
                (batch) {
                  return DropdownMenuItem<String>(
                    value: batch.id,
                    child: Text(
                      '${batch.productName} - ${batch.batchCode}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                final batch = batches.firstWhere(
                  (item) => item.id == value,
                );

                _selectBatch(batch);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _openScanner,
                icon: const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 19,
                ),
                label: const Text(
                  'Scan QR Code Batch',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _mainGreen,
                  side: const BorderSide(
                    color: _mainGreen,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInlineError(
    String message,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: Colors.red.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchInformation(
    BatchModel batch,
  ) {
    final receivedAt = batch.receivedAt.toDate();

    final storedDays = _calculateStoredDays(
      receivedAt,
    );

    final location = batch.storageLocation.trim().isEmpty
        ? '-'
        : batch.storageLocation.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD7E7D7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: _mainGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Informasi Batch',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInformationRow(
            'Produk',
            batch.productName,
          ),
          _buildInformationRow(
            'Kode Batch',
            batch.batchCode,
          ),
          _buildInformationRow(
            'Tanggal Masuk',
            _formatDate(receivedAt),
          ),
          _buildInformationRow(
            'Usia Penyimpanan',
            '$storedDays hari',
          ),
          _buildInformationRow(
            'Sisa Stok',
            '${batch.remainingQty} '
                '${batch.unit.trim().isEmpty ? 'karung' : batch.unit}',
          ),
          _buildInformationRow(
            'Lokasi',
            location,
          ),
        ],
      ),
    );
  }

  Widget _buildInformationRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 11.5,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 11.5,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentCondition(
    String batchId,
  ) {
    return StreamBuilder<BatchConditionCheckModel?>(
      stream: _conditionRepository.getCurrentConditionStream(
        batchId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return _buildInlineError(
            'Gagal memuat kondisi terakhir.',
          );
        }

        final condition = snapshot.data;

        if (condition == null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.black12,
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  color: Colors.black45,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Batch ini belum pernah diperiksa. '
                    'Silakan lengkapi form pemeriksaan di bawah.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final needsAttention = condition.needsAttention;

        final statusColor =
            needsAttention ? Colors.orange.shade800 : _mainGreen;

        final backgroundColor =
            needsAttention ? Colors.orange.shade50 : const Color(0xFFF1F8F1);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: statusColor.withOpacity(0.30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(
                        0.12,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      needsAttention
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      color: statusColor,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kondisi Terakhir',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 10.5,
                          ),
                        ),
                        Text(
                          condition.statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInformationRow(
                'Pemeriksa',
                condition.checkedByName,
              ),
              _buildInformationRow(
                'Tanggal',
                _formatDateTime(
                  condition.checkedAt.toDate(),
                ),
              ),
              if (condition.findings.isNotEmpty) ...[
                const SizedBox(height: 4),
                const Text(
                  'Temuan:',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 5),
                ...condition.findings.map(
                  (finding) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: 3,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              finding,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildConditionDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: _darkGreen,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.black54,
          fontSize: 12,
        ),
        prefixIcon: Icon(
          icon,
          color: _darkGreen,
          size: 20,
        ),
        filled: true,
        fillColor: const Color(0xFFF9FBF9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFD7E7D7),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: _mainGreen,
            width: 1.4,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildInspectionForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(
          title: 'Form Pemeriksaan',
          subtitle: 'Pilih kondisi yang sesuai dengan hasil pemeriksaan '
              'fisik pada batch.',
        ),
        const SizedBox(height: 18),
        _buildConditionDropdown(
          label: 'Kondisi Kemasan',
          icon: Icons.inventory_outlined,
          value: _packagingCondition,
          items: const [
            DropdownMenuItem(
              value: BatchConditionRepository.packagingGood,
              child: Text('Baik'),
            ),
            DropdownMenuItem(
              value: BatchConditionRepository.packagingProblem,
              child: Text('Bermasalah'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _packagingCondition = value;
            });
          },
        ),
        const SizedBox(height: 13),
        _buildConditionDropdown(
          label: 'Bau Beras',
          icon: Icons.air_rounded,
          value: _odorCondition,
          items: const [
            DropdownMenuItem(
              value: BatchConditionRepository.odorNormal,
              child: Text('Normal'),
            ),
            DropdownMenuItem(
              value: BatchConditionRepository.odorAbnormal,
              child: Text('Tidak Normal'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _odorCondition = value;
            });
          },
        ),
        const SizedBox(height: 13),
        _buildConditionDropdown(
          label: 'Hama / Kutu',
          icon: Icons.bug_report_outlined,
          value: _pestCondition,
          items: const [
            DropdownMenuItem(
              value: BatchConditionRepository.pestNone,
              child: Text('Tidak Ada'),
            ),
            DropdownMenuItem(
              value: BatchConditionRepository.pestPresent,
              child: Text('Ada'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _pestCondition = value;
            });
          },
        ),
        const SizedBox(height: 13),
        _buildConditionDropdown(
          label: 'Kondisi Fisik Beras',
          icon: Icons.grain_rounded,
          value: _physicalCondition,
          items: const [
            DropdownMenuItem(
              value: BatchConditionRepository.physicalNormal,
              child: Text('Normal'),
            ),
            DropdownMenuItem(
              value: BatchConditionRepository.physicalChanged,
              child: Text('Ada Perubahan'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _physicalCondition = value;
            });
          },
        ),
        const SizedBox(height: 13),
        _buildConditionDropdown(
          label: 'Tempat Penyimpanan',
          icon: Icons.warehouse_outlined,
          value: _storageCondition,
          items: const [
            DropdownMenuItem(
              value: BatchConditionRepository.storageDry,
              child: Text('Kering'),
            ),
            DropdownMenuItem(
              value: BatchConditionRepository.storageHumid,
              child: Text('Lembap'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _storageCondition = value;
            });
          },
        ),
        const SizedBox(height: 13),
        TextField(
          controller: _notesController,
          minLines: 3,
          maxLines: 4,
          maxLength: 500,
          style: const TextStyle(
            fontSize: 12.5,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            labelText: 'Catatan Pemeriksaan',
            hintText: 'Opsional, contoh: bagian bawah karung terasa lembap.',
            labelStyle: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
            hintStyle: const TextStyle(
              color: Colors.black38,
              fontSize: 11.5,
            ),
            alignLabelWithHint: true,
            filled: true,
            fillColor: const Color(0xFFF9FBF9),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFD7E7D7),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: _mainGreen,
                width: 1.4,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildSaveButton() {
    final disabled = _isSaving || !_isFormComplete;

    return Center(
      child: GestureDetector(
        onTap: disabled ? null : _saveConditionCheck,
        child: AnimatedOpacity(
          duration: const Duration(
            milliseconds: 150,
          ),
          opacity: disabled ? 0.50 : 1,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
            ),
            decoration: BoxDecoration(
              gradient: _primaryGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 5,
                  offset: const Offset(1, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSaving)
                  const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(
                    Icons.save_outlined,
                    color: Colors.white,
                    size: 17,
                  ),
                const SizedBox(width: 7),
                Text(
                  _isSaving ? 'Menyimpan...' : 'Simpan Pemeriksaan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistory(
    String batchId,
  ) {
    return StreamBuilder<List<BatchConditionCheckModel>>(
      stream: _conditionRepository.getHistoryStream(
        batchId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _mainGreen,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildInlineError(
            'Gagal memuat riwayat pemeriksaan.',
          );
        }

        final history = snapshot.data ?? const [];

        if (history.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.black12,
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: Colors.black38,
                  size: 32,
                ),
                SizedBox(height: 8),
                Text(
                  'Belum ada riwayat pemeriksaan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        final visible = history.take(10).toList();

        return Column(
          children: visible.map(
            (item) {
              final needsAttention = item.needsAttention;

              final color =
                  needsAttention ? Colors.orange.shade800 : _mainGreen;

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(
                  bottom: 10,
                ),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: color.withOpacity(0.20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        0.04,
                      ),
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        needsAttention
                            ? Icons.warning_amber_rounded
                            : Icons.check_rounded,
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.statusLabel,
                            style: TextStyle(
                              color: color,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatDateTime(
                              item.checkedAt.toDate(),
                            ),
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 10.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Pemeriksa: '
                            '${item.checkedByName}',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 11,
                            ),
                          ),
                          if (item.findings.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              item.findings.join(
                                ', ',
                              ),
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 10.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                          if (item.notes.trim().isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              'Catatan: '
                              '${item.notes.trim()}',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 10.5,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ).toList(),
        );
      },
    );
  }

  Widget _buildMainContent() {
    final batch = _selectedBatch;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 620,
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.black12,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                          0.05,
                        ),
                        blurRadius: 10,
                        offset: const Offset(
                          0,
                          4,
                        ),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(
                        title: 'Pilih Batch yang Diperiksa',
                        subtitle:
                            'Pilih batch aktif dari daftar atau scan QR Code yang terdapat pada batch.',
                      ),
                      const SizedBox(height: 14),
                      _buildInformationBox(),
                      const SizedBox(height: 18),
                      _buildBatchSelector(),
                      if (batch != null) ...[
                        const SizedBox(height: 20),
                        _buildBatchInformation(
                          batch,
                        ),
                        const SizedBox(height: 14),
                        _buildCurrentCondition(
                          batch.id,
                        ),
                      ],
                    ],
                  ),
                ),
                if (batch != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.black12,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            0.05,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _buildInspectionForm(),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.black12,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            0.05,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(
                          title: 'Riwayat Pemeriksaan',
                          subtitle:
                              'Riwayat tetap disimpan meskipun hasil pemeriksaan terbaru kembali Normal.',
                        ),
                        const SizedBox(height: 14),
                        _buildHistory(
                          batch.id,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: _buildAppBar(),
      body: _buildMainContent(),
    );
  }
}

class _ConditionBatchScannerPage extends StatefulWidget {
  const _ConditionBatchScannerPage();

  @override
  State<_ConditionBatchScannerPage> createState() =>
      _ConditionBatchScannerPageState();
}

class _ConditionBatchScannerPageState
    extends State<_ConditionBatchScannerPage> {
  final BatchRepository _batchRepository = BatchRepository();

  static const Color _darkGreen = Color(0xFF015816);
  static const Color _mainGreen = Color(0xFF038E1B);
  static const Color _lightGreen = Color(0xFF84E977);

  static const LinearGradient _primaryGradient = LinearGradient(
    colors: [
      _darkGreen,
      _mainGreen,
      _lightGreen,
    ],
    stops: [0, 0.5, 1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  bool _isProcessing = false;

  void _showSnackBar(
    String message,
    Color color,
  ) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

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
          left: 16,
          right: 16,
          bottom: 24,
        ),
      ),
    );
  }

  Future<void> _handleScan(
    String value,
  ) async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final batch = await _batchRepository.getBatchByQrValue(
        value.trim(),
      );

      if (!mounted) {
        return;
      }

      if (batch == null) {
        _showSnackBar(
          'Batch tidak ditemukan.',
          Colors.redAccent,
        );

        setState(() {
          _isProcessing = false;
        });

        return;
      }

      final active = batch.status.toLowerCase().trim() == 'active' &&
          batch.remainingQty > 0;

      if (!active) {
        _showSnackBar(
          'Batch sudah tidak aktif atau stok telah habis.',
          Colors.orange.shade800,
        );

        setState(() {
          _isProcessing = false;
        });

        return;
      }

      Navigator.pop(
        context,
        batch,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(
        'Gagal membaca QR Code: $error',
        Colors.redAccent,
      );

      setState(() {
        _isProcessing = false;
      });
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
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
          'SCAN KONDISI BATCH',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.1,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: _primaryGradient,
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
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              onDetect: (
                BarcodeCapture capture,
              ) {
                if (capture.barcodes.isEmpty) {
                  return;
                }

                final value = capture.barcodes.first.rawValue;

                if (value == null || value.trim().isEmpty) {
                  return;
                }

                _handleScan(value);
              },
            ),
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _lightGreen,
                  width: 3,
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isProcessing) ...[
                    const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _lightGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ] else ...[
                    const Icon(
                      Icons.qr_code_scanner,
                      color: _lightGreen,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      _isProcessing
                          ? 'Memproses QR Code...'
                          : 'Arahkan kamera ke QR Code batch',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
