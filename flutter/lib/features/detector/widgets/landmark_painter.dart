// lib/features/detector/widgets/landmark_painter.dart
// Draws 21 hand landmarks and skeleton connections over the camera preview.
 
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
 
class LandmarkPainter extends CustomPainter {
  final List<Hand> hands;
  final Size previewSize;
  final bool isFrontCamera;
 
  // MediaPipe hand skeleton connections (pairs of landmark indices)
  static const List<List<int>> _connections = [
    [0, 1], [1, 2], [2, 3], [3, 4],        // Thumb
    [0, 5], [5, 6], [6, 7], [7, 8],        // Index
    [0, 9], [9, 10], [10, 11], [11, 12],   // Middle
    [0, 13], [13, 14], [14, 15], [15, 16], // Ring
    [0, 17], [17, 18], [18, 19], [19, 20], // Pinky
    [5, 9], [9, 13], [13, 17],             // Palm
  ];
 
  const LandmarkPainter({
    required this.hands,
    required this.previewSize,
    this.isFrontCamera = true,
  });
 
  @override
  void paint(Canvas canvas, Size size) {
    if (hands.isEmpty) return;
 
    // Calcular un factor de escala dinámico basado en la resolución.
    // Asumimos 480 como resolución base (para la que se diseñó originalmente).
    final double minDim = size.width < size.height ? size.width : size.height;
    final double scale = minDim / 480.0;

    final linePaint = Paint()
      // ignore: deprecated_member_use
      ..color = Colors.greenAccent.withOpacity(0.8)
      ..strokeWidth = 2.0 * scale
      ..strokeCap = StrokeCap.round;
 
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
 
    final dotOutlinePaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale;
      
    final double dotRadius = 5.0 * scale;
 
    for (final hand in hands) {
      final lms = hand.landmarks;
      if (lms.isEmpty) continue;
 
      // CameraPreview automatically rotates the camera texture to portrait mode,
      // but MediaPipe receives the raw landscape image from the sensor.
      // Therefore, we must map the raw landscape coordinates (nx, ny) to our 
      // upright portrait canvas.
      Offset toScreen(Landmark lm) {
        double nx = lm.x;
        double ny = lm.y;

        double finalX;
        double finalY;

        if (isFrontCamera) {
          // Mapping for mirrored front camera upright portrait
          finalX = 1.0 - ny;
          finalY = 1.0 - nx;
        } else {
          // Mapping for unmirrored back camera upright portrait
          finalX = 1.0 - ny;
          finalY = nx;
        }

        return Offset(finalX * size.width, finalY * size.height);
      }
 
      // Draw connections first (under the dots)
      for (final conn in _connections) {
        if (conn[0] < lms.length && conn[1] < lms.length) {
          canvas.drawLine(
            toScreen(lms[conn[0]]),
            toScreen(lms[conn[1]]),
            linePaint,
          );
        }
      }
 
      // Draw landmark dots on top
      for (final lm in lms) {
        final pos = toScreen(lm);
        canvas.drawCircle(pos, dotRadius, dotPaint);
        canvas.drawCircle(pos, dotRadius, dotOutlinePaint);
      }
    }
  }
 
  @override
  bool shouldRepaint(LandmarkPainter oldDelegate) =>
      oldDelegate.hands != hands;
}
