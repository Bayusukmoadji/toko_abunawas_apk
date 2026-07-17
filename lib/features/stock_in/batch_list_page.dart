import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/models/batch_model.dart';
import '../../data/repositories/batch_repository.dart';
import 'batch_detail_page.dart';

class BatchListPage extends StatefulWidget {
  const BatchListPage({super.key});

  @override
  State<BatchListPage> createState() => _BatchListPageState();
}

class _BatchListPageState extends State<BatchListPage> {
  final BatchRepository _batchRepository = BatchRepository();

  final TextEditingController _searchController = TextEditingController();

  static const int _pageLimit = 20;

  late Future<List<BatchProductFilterOption>> _productOptionsFuture;

  String _selectedStatusFilter = 'Aktif';
  String _selectedProductId = '';
  DateTime? _selectedReceivedDate;
  String _appliedSearchQuery = '';

  List<BatchModel> _pagedBatches = [];

  DocumentSnapshot<Map<String, dynamic>>? _lastBatchDocument;

  bool _isLoadingPage = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;

  Object? _pageError;

  int _queryVersion = 0;

  final BoxShadow _softShadow = BoxShadow(
    color: Colors.black.withOpacity(0.07),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  bool get _isActiveStatus {
    return _selectedStatusFilter == 'Aktif';
  }

  bool get _isSearchDirty {
    return _searchController.text.trim() != _appliedSearchQuery;
  }

  bool get _hasFilter {
    return _selectedProductId.isNotEmpty ||
        _selectedReceivedDate != null ||
        _appliedSearchQuery.isNotEmpty ||
        _selectedStatusFilter != 'Aktif';
  }

  @override
  void initState() {
    super.initState();

    _productOptionsFuture = _batchRepository.getBatchProductFilterOptions();

    _searchController.addListener(
      _onSearchChanged,
    );
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(
        _onSearchChanged,
      )
      ..dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  DateTime _dateOnly(DateTime value) {
    final localDate = value.toLocal();

    return DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  bool _isBatchEmpty(BatchModel batch) {
    final status = batch.status.toLowerCase().trim();

    return status == 'empty' || status == 'depleted' || batch.remainingQty <= 0;
  }

  Color _getBatchStatusColor(
    BatchModel batch,
  ) {
    return _isBatchEmpty(batch) ? Colors.red.shade500 : Colors.green.shade600;
  }

  IconData _getBatchStatusIcon(
    BatchModel batch,
  ) {
    return _isBatchEmpty(batch)
        ? Icons.cancel_outlined
        : Icons.inventory_2_outlined;
  }

  String _getBatchStatusText(
    BatchModel batch,
  ) {
    return _isBatchEmpty(batch) ? 'Habis' : 'Aktif';
  }

  String _getUnit(BatchModel batch) {
    final unit = batch.unit.trim();

    return unit.isEmpty ? 'karung' : unit;
  }

  String _cleanError(Object? error) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        )
        .replaceFirst(
          'FirebaseException: ',
          '',
        );
  }

  Future<void> _loadPagedBatches({
    required bool reset,
  }) async {
    if (_isActiveStatus) {
      return;
    }

    if (!reset && (_isLoadingMore || !_hasMore)) {
      return;
    }

    final currentVersion = reset ? ++_queryVersion : _queryVersion;

    if (reset) {
      setState(() {
        _pagedBatches = [];
        _lastBatchDocument = null;
        _hasMore = false;
        _isLoadingPage = true;
        _isLoadingMore = false;
        _pageError = null;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
        _pageError = null;
      });
    }

    try {
      final result = await _batchRepository.getBatchesPage(
        statusFilter: _selectedStatusFilter,
        productId: _selectedProductId.isEmpty ? null : _selectedProductId,
        receivedDate: _selectedReceivedDate,
        searchQuery: _appliedSearchQuery,
        limit: _pageLimit,
        startAfterDocument: reset ? null : _lastBatchDocument,
      );

      if (!mounted || currentVersion != _queryVersion) {
        return;
      }

      setState(() {
        _pagedBatches = reset
            ? result.batches
            : [
                ..._pagedBatches,
                ...result.batches,
              ];

        _lastBatchDocument = result.lastDocument;

        _hasMore = result.hasMore;
        _isLoadingPage = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted || currentVersion != _queryVersion) {
        return;
      }

      setState(() {
        _pageError = error;
        _isLoadingPage = false;
        _isLoadingMore = false;
      });
    }
  }

  void _setStatusFilter(String status) {
    if (_selectedStatusFilter == status) {
      return;
    }

    _appliedSearchQuery = _searchController.text.trim();

    setState(() {
      _selectedStatusFilter = status;
      _pageError = null;
    });

    if (status == 'Aktif') {
      _queryVersion++;

      setState(() {
        _pagedBatches = [];
        _lastBatchDocument = null;
        _hasMore = false;
        _isLoadingPage = false;
        _isLoadingMore = false;
      });

      return;
    }

    _loadPagedBatches(
      reset: true,
    );
  }

  void _setProductFilter(
    String productId,
  ) {
    if (_selectedProductId == productId) {
      return;
    }

    setState(() {
      _selectedProductId = productId;
    });

    if (!_isActiveStatus) {
      _loadPagedBatches(
        reset: true,
      );
    }
  }

  void _applySearch() {
    FocusScope.of(context).unfocus();

    _appliedSearchQuery = _searchController.text.trim();

    if (_isActiveStatus) {
      setState(() {});
      return;
    }

    _loadPagedBatches(
      reset: true,
    );
  }

  void _clearSearch() {
    _searchController.clear();
    _appliedSearchQuery = '';

    if (_isActiveStatus) {
      setState(() {});
      return;
    }

    _loadPagedBatches(
      reset: true,
    );
  }

  Future<void> _pickReceivedDate() async {
    final today = _dateOnly(DateTime.now());

    var initialDate = _selectedReceivedDate ?? today;

    if (initialDate.isAfter(today)) {
      initialDate = today;
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: today,
      helpText: 'Pilih Tanggal Masuk Batch',
      cancelText: 'Batal',
      confirmText: 'Pilih',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedReceivedDate = _dateOnly(pickedDate);
    });

    if (!_isActiveStatus) {
      _loadPagedBatches(
        reset: true,
      );
    }
  }

  void _clearReceivedDate() {
    if (_selectedReceivedDate == null) {
      return;
    }

    setState(() {
      _selectedReceivedDate = null;
    });

    if (!_isActiveStatus) {
      _loadPagedBatches(
        reset: true,
      );
    }
  }

  void _resetFilter() {
    _queryVersion++;

    setState(() {
      _selectedStatusFilter = 'Aktif';
      _selectedProductId = '';
      _selectedReceivedDate = null;
      _appliedSearchQuery = '';
      _pagedBatches = [];
      _lastBatchDocument = null;
      _hasMore = false;
      _isLoadingPage = false;
      _isLoadingMore = false;
      _pageError = null;
      _searchController.clear();
    });
  }

  void _reloadProductOptions() {
    setState(() {
      _productOptionsFuture = _batchRepository.getBatchProductFilterOptions();
    });
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
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildCleanCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E5E5),
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

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF038E1B),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFDADADA),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF038E1B),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildStatusFilterChip(
    String status,
  ) {
    final isSelected = _selectedStatusFilter == status;

    IconData icon;

    switch (status) {
      case 'Aktif':
        icon = Icons.inventory_2_outlined;
        break;
      case 'Habis':
        icon = Icons.cancel_outlined;
        break;
      default:
        icon = Icons.all_inclusive;
    }

    return Expanded(
      child: InkWell(
        onTap: () {
          _setStatusFilter(status);
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 180,
          ),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [
                      Color(0xFF015816),
                      Color(0xFF038E1B),
                      Color(0xFF84E977),
                    ],
                    stops: [
                      0,
                      0.55,
                      1,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(
              14,
            ),
            border: Border.all(
              color: isSelected
                  ? const Color(
                      0xFF038E1B,
                    )
                  : const Color(
                      0xFFDADADA,
                    ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : Colors.black54,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 46,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF015816),
            Color(0xFF038E1B),
            Color(0xFF84E977),
          ],
          stops: [0, 0.55, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              0.11,
            ),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
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

  Widget _buildFilterCard(
    List<BatchProductFilterOption> productOptions,
  ) {
    final selectedProductExists = _selectedProductId.isEmpty ||
        productOptions.any(
          (option) => option.id == _selectedProductId,
        );

    final effectiveProductId = selectedProductExists ? _selectedProductId : '';

    final helperText = _isActiveStatus
        ? 'Batch aktif ditampilkan '
            'secara realtime tanpa '
            'pagination. Pencarian '
            'mencakup semua atribut '
            'batch.'
        : 'Riwayat dicari langsung '
            'pada seluruh data '
            'Firestore dan ditampilkan '
            '$_pageLimit data per '
            'pemuatan.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: 'Pencarian dan Filter Batch',
          subtitle: helperText,
        ),
        const SizedBox(height: 12),
        _buildCleanCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cari Batch',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) {
                        _applySearch();
                      },
                      decoration: _inputDecoration(
                        label: 'Pencarian Semua Atribut',
                        hint: 'Ramos, A1, Bayu, BATCH-..., 0...',
                        icon: Icons.search_rounded,
                        suffixIcon: _searchController.text.trim().isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Hapus pencarian',
                                onPressed: _clearSearch,
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.black54,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 92,
                    child: _buildPrimaryButton(
                      label: 'Cari',
                      icon: Icons.search_rounded,
                      onTap: _applySearch,
                    ),
                  ),
                ],
              ),
              if (_isSearchDirty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(
                      10,
                    ),
                    border: Border.all(
                      color: Colors.orange.shade200,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.orange,
                      ),
                      SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Tekan tombol Cari '
                          'untuk menerapkan '
                          'kata pencarian terbaru.',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Produk / Merk Beras',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  effectiveProductId,
                ),
                value: effectiveProductId,
                isExpanded: true,
                decoration: _inputDecoration(
                  label: 'Filter Produk',
                  hint: 'Pilih produk',
                  icon: Icons.inventory_2_outlined,
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text(
                      'Semua Produk / '
                      'Merk Beras',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...productOptions.map(
                    (option) {
                      final codeText =
                          option.code.trim().isEmpty ? '' : ' (${option.code})';

                      return DropdownMenuItem<String>(
                        value: option.id,
                        child: Text(
                          '${option.name}'
                          '$codeText',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                          ),
                        ),
                      );
                    },
                  ),
                ],
                onChanged: (productId) {
                  if (productId != null) {
                    _setProductFilter(
                      productId,
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Status Batch',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatusFilterChip(
                    'Aktif',
                  ),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip(
                    'Habis',
                  ),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip(
                    'Semua',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildPrimaryButton(
                      label: _selectedReceivedDate == null
                          ? 'Semua Tanggal'
                          : _formatDate(
                              _selectedReceivedDate!,
                            ),
                      icon: Icons.calendar_month_outlined,
                      onTap: _pickReceivedDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _resetFilter,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          size: 17,
                        ),
                        label: const Text(
                          'Reset Filter',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(
                            0xFF038E1B,
                          ),
                          side: const BorderSide(
                            color: Color(
                              0xFF038E1B,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_selectedReceivedDate != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFFF1F8F1,
                    ),
                    borderRadius: BorderRadius.circular(
                      12,
                    ),
                    border: Border.all(
                      color: const Color(
                        0xFFC8E6C9,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event_available_outlined,
                        size: 17,
                        color: Color(
                          0xFF038E1B,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tanggal masuk aktif: '
                          '${_formatDate(_selectedReceivedDate!)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Hapus filter tanggal',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: _clearReceivedDate,
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(
    BatchModel batch,
  ) {
    final statusColor = _getBatchStatusColor(batch);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: statusColor.withOpacity(0.35),
        ),
      ),
      child: Text(
        _getBatchStatusText(batch),
        style: TextStyle(
          color: statusColor,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 13,
            color: Colors.black45,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10.5,
                color: Colors.black54,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(
    BatchModel batch,
  ) {
    final receivedDate = batch.receivedAt.toDate();

    final location = batch.storageLocation.trim().isEmpty
        ? '-'
        : batch.storageLocation.trim();

    final statusColor = _getBatchStatusColor(batch);

    final statusIcon = _getBatchStatusIcon(batch);

    final unit = _getUnit(batch);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.18),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BatchDetailPage(
                  batch: batch,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: statusColor.withOpacity(
                        0.15,
                      ),
                      child: Icon(
                        statusIcon,
                        size: 17,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: 2,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              batch.productName.trim().isEmpty
                                  ? 'Produk '
                                      'Tanpa Nama'
                                  : batch.productName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(
                              height: 2,
                            ),
                            Text(
                              batch.batchCode.trim().isEmpty
                                  ? batch.id
                                  : batch.batchCode,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 4,
                      ),
                      child: _buildStatusChip(
                        batch,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Padding(
                      padding: EdgeInsets.only(
                        top: 4,
                      ),
                      child: Icon(
                        Icons.keyboard_double_arrow_right,
                        color: Colors.black54,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 44,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        icon: Icons.calendar_today_outlined,
                        text: 'Tanggal masuk: '
                            '${_formatDate(receivedDate)}',
                      ),
                      _buildInfoRow(
                        icon: Icons.inventory_outlined,
                        text: 'Sisa stok: '
                            '${batch.remainingQty} '
                            '$unit dari '
                            '${batch.initialQty} '
                            '$unit',
                      ),
                      _buildInfoRow(
                        icon: Icons.location_on_outlined,
                        text: 'Lokasi: $location',
                      ),
                      if (batch.createdByName.trim().isNotEmpty)
                        _buildInfoRow(
                          icon: Icons.person_outline,
                          text: 'Dicatat oleh: '
                              '${batch.createdByName.trim()}',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.orange.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _hasFilter ? Icons.search_off_rounded : Icons.inventory_2_outlined,
            color: Colors.orange.shade700,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasFilter
                      ? 'Data Tidak '
                          'Ditemukan'
                      : 'Belum Ada Batch',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _hasFilter
                      ? 'Tidak ada batch '
                          'yang sesuai dengan '
                          'pencarian atau '
                          'filter yang dipilih.'
                      : 'Belum ada data batch '
                          'yang tersimpan.',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (_hasFilter) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _resetFilter,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 17,
                    ),
                    label: const Text(
                      'Reset Pencarian '
                      'dan Filter',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(
                        0xFF038E1B,
                      ),
                      side: const BorderSide(
                        color: Color(
                          0xFF038E1B,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          12,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(
    String message,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF038E1B),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState({
    required Object? error,
    required VoidCallback onRetry,
  }) {
    final message = _cleanError(error);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.shade200,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade600,
            size: 38,
          ),
          const SizedBox(height: 12),
          Text(
            'Gagal memuat data batch',
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 17,
            ),
            label: const Text(
              'Coba Lagi',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    if (!_hasMore && !_isLoadingMore) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(
        top: 4,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: OutlinedButton.icon(
          onPressed: _isLoadingMore
              ? null
              : () {
                  _loadPagedBatches(
                    reset: false,
                  );
                },
          icon: _isLoadingMore
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(
                      0xFF038E1B,
                    ),
                  ),
                )
              : const Icon(
                  Icons.expand_more_rounded,
                ),
          label: Text(
            _isLoadingMore ? 'Memuat...' : 'Muat Lebih Banyak',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(
              0xFF038E1B,
            ),
            side: const BorderSide(
              color: Color(
                0xFF038E1B,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataSection({
    required List<BatchModel> batches,
    required bool isPaginated,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _buildSectionTitle(
                title: 'Data Batch',
                subtitle: isPaginated
                    ? 'Riwayat dimuat '
                        'bertahap sebanyak '
                        '$_pageLimit data.'
                    : 'Batch aktif '
                        'diperbarui realtime '
                        'tanpa pagination.',
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(
                  0xFFF1F8F1,
                ),
                borderRadius: BorderRadius.circular(
                  99,
                ),
                border: Border.all(
                  color: const Color(
                    0xFFC8E6C9,
                  ),
                ),
              ),
              child: Text(
                '${batches.length} data',
                style: const TextStyle(
                  color: Color(
                    0xFF038E1B,
                  ),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (batches.isEmpty)
          _buildEmptyState()
        else ...[
          ...batches.map(
            _buildBatchCard,
          ),
          if (isPaginated) _buildLoadMoreButton(),
        ],
      ],
    );
  }

  Widget _buildActiveDataSection() {
    return StreamBuilder<List<BatchModel>>(
      stream: _batchRepository.getActiveBatchesStream(
        productId: _selectedProductId.isEmpty ? null : _selectedProductId,
        receivedDate: _selectedReceivedDate,
        searchQuery: _appliedSearchQuery,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoadingState(
            'Memuat batch aktif...',
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(
            error: snapshot.error,
            onRetry: () {
              setState(() {});
            },
          );
        }

        return _buildDataSection(
          batches: snapshot.data ?? <BatchModel>[],
          isPaginated: false,
        );
      },
    );
  }

  Widget _buildPagedDataSection() {
    if (_isLoadingPage && _pagedBatches.isEmpty) {
      return _buildLoadingState(
        'Memuat riwayat batch...',
      );
    }

    if (_pageError != null && _pagedBatches.isEmpty) {
      return _buildErrorState(
        error: _pageError,
        onRetry: () {
          _loadPagedBatches(
            reset: true,
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDataSection(
          batches: _pagedBatches,
          isPaginated: true,
        ),
        if (_pageError != null && _pagedBatches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              top: 8,
            ),
            child: Text(
              'Sebagian data gagal '
              'dimuat: '
              '${_cleanError(_pageError)}',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
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
          'DAFTAR BATCH',
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
              stops: [0, 0.5, 1],
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

  Widget _buildPageContent(
    List<BatchProductFilterOption> productOptions,
  ) {
    return SafeArea(
      child: SingleChildScrollView(
        key: const PageStorageKey(
          'batch_list_scroll',
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 24,
        ),
        physics: const ClampingScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 620,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  18,
                ),
                border: Border.all(
                  color: Colors.black12,
                  width: 1,
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
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterCard(
                    productOptions,
                  ),
                  const SizedBox(
                    height: 26,
                  ),
                  if (_isActiveStatus)
                    _buildActiveDataSection()
                  else
                    _buildPagedDataSection(),
                ],
              ),
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
      body: FutureBuilder<List<BatchProductFilterOption>>(
        future: _productOptionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return _buildLoadingState(
              'Memuat daftar produk...',
            );
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(
                16,
              ),
              child: _buildErrorState(
                error: snapshot.error,
                onRetry: _reloadProductOptions,
              ),
            );
          }

          return _buildPageContent(
            snapshot.data ?? <BatchProductFilterOption>[],
          );
        },
      ),
    );
  }
}
