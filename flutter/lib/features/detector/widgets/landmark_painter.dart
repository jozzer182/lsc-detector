// lib/features/detector/widgets/landmark_painter.dart
// Draws 21 hand landmarks and skeleton connections over the camera preview.
 
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
 
class LandmarkPainter extends CustomPainter {
  final List<Hand> hands;
  final Size previewSize;
  final bool isFrontCamera;
  /// The number of clockwise quarter turns applied by RotatedBox.
  /// Must match the value used to rotate the CameraPreview so that
  /// the landmark coordinates align with the rotated image.
  final int quarterTurns;
 
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
    this.quarterTurns = 0,
  });
 
  @override
  void paint(Canvas canvas, Size size) {
    if (hands.isEmpty) return;
 
    final linePaint = Paint()
      // ignore: deprecated_member_use
      ..color = Colors.greenAccent.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
 
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
 
    final dotOutlinePaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
 
    for (final hand in hands) {
      final lms = hand.landmarks;
      if (lms.isEmpty) continue;
 
      // Map normalized [0,1] landmark coordinates to canvas pixel
      // coordinates, accounting for the RotatedBox rotation.
      //
      // MediaPipe returns landmarks in portrait-corrected space
      // (because we pass sensorOrientation to detect()). But the
      // canvas is pre-rotation (landscape). We need to transform the
      // portrait coords into the landscape canvas so that after
      // RotatedBox rotates everything, landmarks match the preview.
      Offset toScreen(Landmark lm) {
        var nx = lm.x;
        var ny = lm.y;

        // Front camera: mirror x to match the platform's horizontal flip.
        if (isFrontCamera) {
          nx = 1.0 - nx;
        }

        // Transform from portrait-corrected space to pre-rotation
        // landscape canvas space.
        final w = size.width;
        final h = size.height;
        switch ((quarterTurns-1) % 4) {
          case 0:
            return Offset(nx * w, ny * h);
          case 1: // 90° CW: inverse is 90° CCW
            return Offset(ny * w, (1.0 - nx) * h);
          case 2: // 180°: inverse is 180°
            return Offset((1.0 - nx) * w, (1.0 - ny) * h);
          case 3: // 270° CW: inverse is 90° CW
            return Offset((1.0 - ny) * w, nx * h);
          default:
            return Offset(nx * w, ny * h);
        }
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
        canvas.drawCircle(pos, 5, dotPaint);
        canvas.drawCircle(pos, 5, dotOutlinePaint);
      }
    }
  }
 
  @override
  bool shouldRepaint(LandmarkPainter oldDelegate) =>
      oldDelegate.hands != hands ||
      oldDelegate.quarterTurns != oldDelegate.quarterTurns;
}
