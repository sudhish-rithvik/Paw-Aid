import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class BoundingBoxImage extends StatelessWidget {
  final String imageUrl;
  final Map<String, dynamic> rawResponse;

  const BoundingBoxImage({
    super.key,
    required this.imageUrl,
    required this.rawResponse,
  });

  Widget _buildImage(String src, BoxFit fit) {
    if (src.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Center(child: Icon(Icons.pets, color: Colors.grey, size: 40)),
      );
    }
    if (src.startsWith('data:image') || src.length > 500) {
      try {
        final base64String = src.contains(',') ? src.split(',').last : src;
        final bytes = base64Decode(
            base64String.replaceAll('\n', '').replaceAll('\r', '').trim());
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey[200],
            child: const Center(
                child: Icon(Icons.broken_image, color: Colors.grey, size: 40)),
          ),
        );
      } catch (_) {
        return Container(
          color: Colors.grey[200],
          child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 40)),
        );
      }
    } else if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey[200],
          child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 40)),
        ),
      );
    } else if (File(src).existsSync()) {
      return Image.file(
        File(src),
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey[200],
          child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 40)),
        ),
      );
    } else {
      return Image.asset(
        src,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey[200],
          child: const Center(child: Icon(Icons.pets, color: Colors.grey, size: 40)),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final imageMetadata = rawResponse['image'] as Map<String, dynamic>?;
    final double? imageWidth = imageMetadata?['width']?.toDouble();
    final double? imageHeight = imageMetadata?['height']?.toDouble();

    final predictionsList = rawResponse['predictions'] as List<dynamic>? ?? [];
    final predictions = predictionsList.cast<Map<String, dynamic>>();

    // If we don't have dimensions or predictions, just show the image normally
    if (imageWidth == null || imageHeight == null || predictions.isEmpty) {
      return _buildImage(
        imageUrl,
        BoxFit.cover,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Because we use BoxFit.contain, the image is scaled to fit within the box
        // while preserving aspect ratio. We need to calculate the actual display size
        // of the image inside the box to offset our bounding boxes correctly.
        final double boxWidth = constraints.maxWidth;
        final double boxHeight = constraints.maxHeight;

        final double imageAspectRatio = imageWidth / imageHeight;
        final double boxAspectRatio = boxWidth / boxHeight;

        double displayWidth;
        double displayHeight;
        double offsetX = 0;
        double offsetY = 0;

        if (imageAspectRatio > boxAspectRatio) {
          // Image is wider than the box: width is maxed out, height is scaled
          displayWidth = boxWidth;
          displayHeight = boxWidth / imageAspectRatio;
          offsetY = (boxHeight - displayHeight) / 2;
        } else {
          // Image is taller than the box: height is maxed out, width is scaled
          displayHeight = boxHeight;
          displayWidth = boxHeight * imageAspectRatio;
          offsetX = (boxWidth - displayWidth) / 2;
        }

        final double scaleX = displayWidth / imageWidth;
        final double scaleY = displayHeight / imageHeight;

        return Stack(
          children: [
            SizedBox(
              width: boxWidth,
              height: boxHeight,
              child: _buildImage(
                imageUrl,
                BoxFit.contain,
              ),
            ),
            Positioned(
              left: offsetX,
              top: offsetY,
              width: displayWidth,
              height: displayHeight,
              child: CustomPaint(
                painter: _BoundingBoxPainter(
                  predictions: predictions,
                  scaleX: scaleX,
                  scaleY: scaleY,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> predictions;
  final double scaleX;
  final double scaleY;

  _BoundingBoxPainter({
    required this.predictions,
    required this.scaleX,
    required this.scaleY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final fillPaint = Paint()
      ..color = Colors.redAccent.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    for (final pred in predictions) {
      final double cx = (pred['x'] as num).toDouble();
      final double cy = (pred['y'] as num).toDouble();
      final double w = (pred['width'] as num).toDouble();
      final double h = (pred['height'] as num).toDouble();
      final String className = pred['class'] as String? ?? 'Object';
      final double confidence = (pred['confidence'] as num?)?.toDouble() ?? 0.0;

      // Roboflow returns x, y as center of the box
      final left = (cx - (w / 2)) * scaleX;
      final top = (cy - (h / 2)) * scaleY;
      final width = w * scaleX;
      final height = h * scaleY;

      final rect = Rect.fromLTWH(left, top, width, height);

      // Draw box
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, boxPaint);

      // Draw label
      final textSpan = TextSpan(
        text: ' ${className.toUpperCase()} ${(confidence * 100).toStringAsFixed(0)}% ',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.redAccent,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(left, top - textPainter.height > 0 ? top - textPainter.height : top),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter oldDelegate) {
    return true;
  }
}
