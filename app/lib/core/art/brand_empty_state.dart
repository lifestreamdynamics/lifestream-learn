import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Generic empty-state widget composed of a [CustomPainter] illustration,
/// a title, an optional subtitle, and an optional action widget.
class BrandEmptyState extends StatelessWidget {
  const BrandEmptyState({
    required this.painter,
    required this.title,
    this.subtitle,
    this.action,
    this.size = 220,
    super.key,
  });

  final CustomPainter painter;
  final String title;
  final String? subtitle;
  final Widget? action;
  final double size;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(size: Size.square(size), painter: painter),
            const SizedBox(height: 24),
            Text(
              title,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Base circuit-swirl motif
// ---------------------------------------------------------------------------

/// Draws 3–4 smooth Bezier arcs at different radii with "node" dots at
/// endpoints. Used as the shared background motif for all empty-state
/// painters.
///
/// Uses [scheme.primary] for main strokes and a semi-transparent variant
/// for secondary strokes.
class CircuitSwirlPainter extends CustomPainter {
  const CircuitSwirlPainter({required this.scheme});

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    _drawSwirl(canvas, size, scheme);
  }

  @override
  bool shouldRepaint(covariant CircuitSwirlPainter old) => false;
}

/// Internal helper so all painters can reuse the swirl without inheriting.
void _drawSwirl(Canvas canvas, Size size, ColorScheme scheme) {
  final cx = size.width / 2;
  final cy = size.height / 2;

  final primaryPaint = Paint()
    ..color = scheme.primary
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round;

  final secondaryPaint = Paint()
    ..color = scheme.primary.withValues(alpha: 0.35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round;

  final nodePaint = Paint()
    ..color = scheme.tertiary
    ..style = PaintingStyle.fill;

  final r1 = size.width * 0.38;
  final r2 = size.width * 0.28;
  final r3 = size.width * 0.18;

  // Arc 1 — outermost, ~270° sweep
  final path1 = Path();
  const startAngle1 = -math.pi * 0.9;
  const sweepAngle1 = math.pi * 1.5;
  final p1Start = Offset(
    cx + r1 * math.cos(startAngle1),
    cy + r1 * math.sin(startAngle1),
  );
  final p1End = Offset(
    cx + r1 * math.cos(startAngle1 + sweepAngle1),
    cy + r1 * math.sin(startAngle1 + sweepAngle1),
  );
  path1.moveTo(p1Start.dx, p1Start.dy);
  path1.arcTo(
    Rect.fromCircle(center: Offset(cx, cy), radius: r1),
    startAngle1,
    sweepAngle1,
    false,
  );
  canvas.drawPath(path1, primaryPaint);

  // Node dots at arc 1 endpoints
  canvas.drawCircle(p1Start, 3.5, nodePaint);
  canvas.drawCircle(p1End, 3.5, nodePaint);

  // Arc 2 — middle radius, ~200° sweep, offset phase
  final path2 = Path();
  const startAngle2 = math.pi * 0.2;
  const sweepAngle2 = math.pi * 1.1;
  final p2Start = Offset(
    cx + r2 * math.cos(startAngle2),
    cy + r2 * math.sin(startAngle2),
  );
  final p2End = Offset(
    cx + r2 * math.cos(startAngle2 + sweepAngle2),
    cy + r2 * math.sin(startAngle2 + sweepAngle2),
  );
  path2.moveTo(p2Start.dx, p2Start.dy);
  path2.arcTo(
    Rect.fromCircle(center: Offset(cx, cy), radius: r2),
    startAngle2,
    sweepAngle2,
    false,
  );
  canvas.drawPath(path2, secondaryPaint);

  canvas.drawCircle(p2Start, 2.5, nodePaint);
  canvas.drawCircle(p2End, 2.5, nodePaint);

  // Arc 3 — inner radius, ~120° sweep
  final path3 = Path();
  const startAngle3 = -math.pi * 0.3;
  const sweepAngle3 = math.pi * 0.65;
  final p3Start = Offset(
    cx + r3 * math.cos(startAngle3),
    cy + r3 * math.sin(startAngle3),
  );
  final p3End = Offset(
    cx + r3 * math.cos(startAngle3 + sweepAngle3),
    cy + r3 * math.sin(startAngle3 + sweepAngle3),
  );
  path3.moveTo(p3Start.dx, p3Start.dy);
  path3.arcTo(
    Rect.fromCircle(center: Offset(cx, cy), radius: r3),
    startAngle3,
    sweepAngle3,
    false,
  );
  canvas.drawPath(path3, primaryPaint);

  canvas.drawCircle(p3Start, 2.0, nodePaint);
  canvas.drawCircle(p3End, 2.0, nodePaint);

  // Connector line from arc1 end to arc2 start — gives circuit-trace feel
  final connectorPaint = Paint()
    ..color = scheme.primary.withValues(alpha: 0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  canvas.drawLine(p1End, p2Start, connectorPaint);
}

// ---------------------------------------------------------------------------
// EmptyFeedPainter
// ---------------------------------------------------------------------------

/// CircuitSwirl background + an open-book glyph (two angled rounded rects).
class EmptyFeedPainter extends CustomPainter {
  const EmptyFeedPainter({required this.scheme});

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    _drawSwirl(canvas, size, scheme);
    _drawBook(canvas, size, scheme);
  }

  void _drawBook(Canvas canvas, Size size, ColorScheme scheme) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final bookPaint = Paint()
      ..color = scheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;

    // Left page — slightly rotated counter-clockwise
    final leftPage = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx - 22, cy),
        width: 36,
        height: 48,
      ),
      const Radius.circular(4),
    );
    canvas.save();
    canvas.translate(cx - 22, cy);
    canvas.rotate(-0.12);
    canvas.translate(-(cx - 22), -cy);
    canvas.drawRRect(leftPage, bookPaint);
    canvas.restore();

    // Right page — slightly rotated clockwise
    final rightPage = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx + 22, cy),
        width: 36,
        height: 48,
      ),
      const Radius.circular(4),
    );
    canvas.save();
    canvas.translate(cx + 22, cy);
    canvas.rotate(0.12);
    canvas.translate(-(cx + 22), -cy);
    canvas.drawRRect(rightPage, bookPaint);
    canvas.restore();

    // Centre spine line
    canvas.drawLine(
      Offset(cx, cy - 24),
      Offset(cx, cy + 24),
      bookPaint,
    );
  }

  @override
  bool shouldRepaint(covariant EmptyFeedPainter old) => false;
}

// ---------------------------------------------------------------------------
// EmptyEnrollmentsPainter
// ---------------------------------------------------------------------------

/// CircuitSwirl background + 3 stacked-and-fanned rounded rects (card stack).
class EmptyEnrollmentsPainter extends CustomPainter {
  const EmptyEnrollmentsPainter({required this.scheme});

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    _drawSwirl(canvas, size, scheme);
    _drawCardStack(canvas, size, scheme);
  }

  void _drawCardStack(Canvas canvas, Size size, ColorScheme scheme) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final cardData = [
      (
        color: scheme.surfaceContainerHigh,
        angle: -0.15,
        dy: 6.0,
      ),
      (
        color: scheme.primaryContainer,
        angle: 0.1,
        dy: 0.0,
      ),
      (
        color: scheme.primary.withValues(alpha: 0.85),
        angle: -0.04,
        dy: -8.0,
      ),
    ];

    for (final card in cardData) {
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + card.dy),
          width: 72,
          height: 48,
        ),
        const Radius.circular(6),
      );
      canvas.save();
      canvas.translate(cx, cy + card.dy);
      canvas.rotate(card.angle);
      canvas.translate(-cx, -(cy + card.dy));
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = card.color
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = scheme.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant EmptyEnrollmentsPainter old) => false;
}

// ---------------------------------------------------------------------------
// EmptySearchPainter
// ---------------------------------------------------------------------------

/// CircuitSwirl background + a magnifier glyph (circle + handle).
class EmptySearchPainter extends CustomPainter {
  const EmptySearchPainter({required this.scheme});

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    _drawSwirl(canvas, size, scheme);
    _drawMagnifier(canvas, size, scheme);
  }

  void _drawMagnifier(Canvas canvas, Size size, ColorScheme scheme) {
    final cx = size.width / 2 - 6;
    final cy = size.height / 2 - 6;
    const radius = 18.0;

    final glassPaint = Paint()
      ..color = scheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Lens circle
    canvas.drawCircle(Offset(cx, cy), radius, glassPaint);

    // Handle — at 45° from centre
    const angle = math.pi * 0.75; // bottom-right
    final handleStart = Offset(
      cx + radius * math.cos(angle),
      cy + radius * math.sin(angle),
    );
    final handleEnd = Offset(
      cx + (radius + 18) * math.cos(angle),
      cy + (radius + 18) * math.sin(angle),
    );
    canvas.drawLine(handleStart, handleEnd, glassPaint);
  }

  @override
  bool shouldRepaint(covariant EmptySearchPainter old) => false;
}
