// lib/features/shared/qr_scanner.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_theme.dart';

/// QR scanner screen using mobile_scanner.
/// Returns the decoded case ID via [onDetected] callback.
class QRScannerScreen extends StatefulWidget {
  final void Function(String caseId) onDetected;

  const QRScannerScreen({super.key, required this.onDetected});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;
    final raw = barcode.rawValue ?? '';

    // Extract case ID from URL or use raw value
    String caseId = raw;
    if (raw.contains('/track/')) {
      caseId = raw.split('/track/').last.trim();
    }

    if (caseId.isNotEmpty) {
      _hasScanned = true;
      widget.onDetected(caseId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Case QR Code'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera feed
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Overlay frame
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // Corner decorations
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                children: [
                  _Corner(top: 0, left: 0, rotate: 0),
                  _Corner(top: 0, right: 0, rotate: 90),
                  _Corner(bottom: 0, right: 0, rotate: 180),
                  _Corner(bottom: 0, left: 0, rotate: 270),
                ],
              ),
            ),
          ),

          // Instruction
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: const Text(
              'Point at the rescue case QR code',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final double? top, left, right, bottom;
  final double rotate;

  const _Corner({this.top, this.left, this.right, this.bottom, required this.rotate});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Transform.rotate(
        angle: rotate * 3.14159 / 180,
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.primary, width: 4),
              left: BorderSide(color: AppColors.primary, width: 4),
            ),
          ),
        ),
      ),
    );
  }
}
