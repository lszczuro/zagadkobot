import 'package:flutter/material.dart';

class RobotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    const bodyColor = Color(0xFFFFFFFF);
    const shadowColor = Color(0xFFD0C8F0);
    const faceColor = Color(0xFFF8F6FF);
    const accentColor = Color(0xFF9B85D0);
    const eyeColor = Color(0xFF5B3D9B);
    const cheekColor = Color(0xFFE8DCFF);

    final paint = Paint()..isAntiAlias = true;

    // ── Body ──────────────────────────────────────────────────────────────
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.68),
        width: w * 0.52,
        height: h * 0.44,
      ),
      const Radius.circular(48),
    );
    paint
      ..color = shadowColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bodyRect.shift(const Offset(0, 4)), paint);
    paint.color = bodyColor;
    canvas.drawRRect(bodyRect, paint);

    // ── Arms ──────────────────────────────────────────────────────────────
    _drawArm(canvas, paint, bodyColor, shadowColor,
        center: Offset(w * 0.18, h * 0.65), angle: -0.3);
    _drawArm(canvas, paint, bodyColor, shadowColor,
        center: Offset(w * 0.82, h * 0.65), angle: 0.3);

    // ── Chest panel ───────────────────────────────────────────────────────
    final panelRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.70),
        width: w * 0.28,
        height: h * 0.18,
      ),
      const Radius.circular(12),
    );
    paint.color = cheekColor;
    canvas.drawRRect(panelRect, paint);

    for (int i = 0; i < 3; i++) {
      paint.color = accentColor.withValues(alpha: 0.6);
      canvas.drawCircle(
        Offset(w * 0.38 + i * w * 0.12, h * 0.70),
        3.5,
        paint,
      );
    }

    // ── Head ──────────────────────────────────────────────────────────────
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.36),
        width: w * 0.46,
        height: h * 0.38,
      ),
      const Radius.circular(40),
    );
    paint.color = shadowColor;
    canvas.drawRRect(headRect.shift(const Offset(0, 3)), paint);
    paint.color = bodyColor;
    canvas.drawRRect(headRect, paint);

    // Face plate
    final faceRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.36),
        width: w * 0.36,
        height: h * 0.28,
      ),
      const Radius.circular(28),
    );
    paint.color = faceColor;
    canvas.drawRRect(faceRect, paint);

    // Eyes
    paint.color = eyeColor;
    canvas.drawCircle(Offset(w * 0.40, h * 0.33), 6, paint);
    canvas.drawCircle(Offset(w * 0.60, h * 0.33), 6, paint);

    // Eye shine
    paint.color = Colors.white;
    canvas.drawCircle(Offset(w * 0.42, h * 0.315), 2, paint);
    canvas.drawCircle(Offset(w * 0.62, h * 0.315), 2, paint);

    // Smile
    final smilePath = Path();
    smilePath.moveTo(w * 0.40, h * 0.40);
    smilePath.quadraticBezierTo(w * 0.50, h * 0.455, w * 0.60, h * 0.40);
    paint
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(smilePath, paint);
    paint.style = PaintingStyle.fill;

    // Cheeks
    paint.color = cheekColor;
    canvas.drawCircle(Offset(w * 0.335, h * 0.39), 8, paint);
    canvas.drawCircle(Offset(w * 0.665, h * 0.39), 8, paint);

    // ── Antenna ───────────────────────────────────────────────────────────
    paint
      ..color = accentColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.5, h * 0.175),
      Offset(w * 0.5, h * 0.10),
      paint,
    );
    paint.style = PaintingStyle.fill;
    paint.color = const Color(0xFF7B5EA7);
    canvas.drawCircle(Offset(w * 0.5, h * 0.085), 7, paint);
    paint.color = Colors.white.withValues(alpha: 0.6);
    canvas.drawCircle(Offset(w * 0.495, h * 0.080), 2.5, paint);
  }

  void _drawArm(
    Canvas canvas,
    Paint paint,
    Color bodyColor,
    Color shadowColor, {
    required Offset center,
    required double angle,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final armRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 22, height: 46),
      const Radius.circular(11),
    );
    paint.color = shadowColor;
    canvas.drawRRect(armRect.shift(const Offset(0, 3)), paint);
    paint.color = bodyColor;
    canvas.drawRRect(armRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
