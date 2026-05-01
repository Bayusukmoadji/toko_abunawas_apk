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
      builder: (context) {
        return AlertDialog(
          title: const Text('Input QR Manual'),
          content: TextField(
            controller: _manualQrController,
            decoration: const InputDecoration(
              labelText: 'QR Value / Batch ID',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final qrValue = _manualQrController.text.trim();

                if (qrValue.isEmpty) {
                  return;
                }

                Navigator.pop(context);
                _handleScan(qrValue);
              },
              child: const Text('Lanjut'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Arahkan kamera ke QR Code batch beras.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _showManualQrDialog,
                    child: const Text('Input QR Manual'),
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
