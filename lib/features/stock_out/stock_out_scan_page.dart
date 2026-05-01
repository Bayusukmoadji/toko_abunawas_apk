import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/models/app_user_model.dart';
import '../../data/repositories/batch_repository.dart';
import 'stock_out_confirm_page.dart';

class StockOutScanPage extends StatefulWidget {
  final AppUserModel user;

  const StockOutScanPage({
    super.key,
    required this.user,
  });

  @override
  State<StockOutScanPage> createState() => _StockOutScanPageState();
}

class _StockOutScanPageState extends State<StockOutScanPage> {
  final BatchRepository _batchRepository = BatchRepository();
  final TextEditingController _manualQrController = TextEditingController();

  bool _isProcessing = false;

  @override
  void dispose() {
    _manualQrController.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String qrValue) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final batch = await _batchRepository.getBatchByQrValue(qrValue);

      if (!mounted) return;

      if (batch == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Batch tidak ditemukan.'),
            backgroundColor: Colors.red,
          ),
        );

        setState(() {
          _isProcessing = false;
        });
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StockOutConfirmPage(
            user: widget.user,
            scannedBatch: batch,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membaca QR Code: $e'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _showManualQrDialog() async {
    _manualQrController.clear();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Input QR Manual'),
          content: TextField(
            controller: _manualQrController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'QR Value / Batch ID',
              hintText: 'Tempel QR Value dari detail batch',
              prefixIcon: Icon(Icons.qr_code_2),
            ),
            onSubmitted: (_) {
              final qrValue = _manualQrController.text.trim();

              if (qrValue.isEmpty) return;

              Navigator.pop(dialogContext);
              _handleScan(qrValue);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final qrValue = _manualQrController.text.trim();

                if (qrValue.isEmpty) return;

                Navigator.pop(dialogContext);
                _handleScan(qrValue);
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Lanjut'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScanFrame() {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 14,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 14,
              left: 14,
              child: _buildCorner(),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: Transform.rotate(
                angle: 1.5708,
                child: _buildCorner(),
              ),
            ),
            Positioned(
              bottom: 14,
              right: 14,
              child: Transform.rotate(
                angle: 3.1416,
                child: _buildCorner(),
              ),
            ),
            Positioned(
              bottom: 14,
              left: 14,
              child: Transform.rotate(
                angle: 4.7124,
                child: _buildCorner(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner() {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Color(0xFF2E7D32),
            width: 5,
          ),
          left: BorderSide(
            color: Color(0xFF2E7D32),
            width: 5,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.72),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.qr_code_scanner,
                color: Colors.white,
                size: 34,
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan QR Code Batch',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Arahkan kamera ke QR Code batch beras yang akan dikeluarkan. Sistem akan memeriksa urutan FIFO sebelum stok keluar disimpan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _showManualQrDialog,
                  icon: const Icon(Icons.keyboard_alt_outlined),
                  label: const Text('Input QR Manual'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text(
                  'Memproses QR Code...',
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Stok Keluar'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (BarcodeCapture capture) {
              final barcodes = capture.barcodes;

              if (barcodes.isEmpty) return;

              final qrValue = barcodes.first.rawValue;

              if (qrValue == null || qrValue.isEmpty) return;

              _handleScan(qrValue);
            },
          ),
          Container(
            color: Colors.black.withOpacity(0.12),
          ),
          _buildScanFrame(),
          _buildBottomPanel(),
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
    );
  }
}
