// lib/features/shared/qr_code_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_theme.dart';

/// Displays a QR code for a rescue case ID.
class QRCodeWidget extends StatelessWidget {
  final String caseId;
  final double size;
  final bool showCopyButton;

  const QRCodeWidget({
    super.key,
    required this.caseId,
    this.size = 200,
    this.showCopyButton = true,
  });

  /// The tracking URL encoded in the QR code.
  String get _trackingUrl => 'https://pawaid.app/track/$caseId';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: QrImageView(
            data: _trackingUrl,
            version: QrVersions.auto,
            size: size,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF0A0E1A),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF0A0E1A),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Case ID label
        Text(
          'Case #${caseId.substring(0, 8).toUpperCase()}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),

        if (showCopyButton) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _trackingUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tracking link copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 14),
            label: const Text('Copy Tracking Link'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}
