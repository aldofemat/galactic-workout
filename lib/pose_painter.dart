import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'theme.dart';

/// Dibuja los keypoints y conexiones del esqueleto detectado.
class PosePainter extends CustomPainter {
  PosePainter(this.poses, this.imageSize, this.rotation);

  final List<Pose> poses;
  final Size imageSize;
  final InputImageRotation rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = AppColors.brandBright
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final linePaint = Paint()
      ..color = AppColors.brandBright.withValues(alpha: 0.7)
      ..strokeWidth = 3;

    for (final pose in poses) {
      // Dibuja cada landmark como un punto
      pose.landmarks.forEach((_, landmark) {
        final point = _scalePoint(
          Offset(landmark.x, landmark.y),
          imageSize,
          size,
          rotation,
        );
        canvas.drawCircle(point, 4, dotPaint);
      });

      // Dibuja las conexiones principales del esqueleto
      void drawLine(PoseLandmarkType a, PoseLandmarkType b) {
        final la = pose.landmarks[a];
        final lb = pose.landmarks[b];
        if (la == null || lb == null) return;
        final pa = _scalePoint(Offset(la.x, la.y), imageSize, size, rotation);
        final pb = _scalePoint(Offset(lb.x, lb.y), imageSize, size, rotation);
        canvas.drawLine(pa, pb, linePaint);
      }

      // Torso y piernas (lo relevante para sentadillas)
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
      drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
      drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
      drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    }
  }

  Offset _scalePoint(
    Offset point,
    Size imageSize,
    Size widgetSize,
    InputImageRotation rotation,
  ) {
    // Ajuste simple para cámara frontal/vertical.
    // Si notas el esqueleto desalineado, este es el punto a calibrar.
    final scaleX = widgetSize.width / imageSize.height;
    final scaleY = widgetSize.height / imageSize.width;
    return Offset(point.dx * scaleX, point.dy * scaleY);
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) => true;
}
