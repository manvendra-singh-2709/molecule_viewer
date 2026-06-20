import 'dart:math';
import 'package:flutter/material.dart';

import '../models/models.dart';

class MoleculeViewer extends StatelessWidget {
  final List<Atom> atoms;
  final List<Bond> bonds;
  final double scale;
  final double rotationX;
  final double rotationY;
  final double rotationZ;

  const MoleculeViewer({
    super.key,
    required this.atoms,
    required this.bonds,
    required this.scale,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: MoleculePainter(
        atoms: atoms,
        bonds: bonds,
        scale: scale,
        rotationX: rotationX,
        rotationY: rotationY,
        rotationZ: rotationZ,
      ),
      size: Size.infinite,
    );
  }
}

class MoleculePainter extends CustomPainter {
  final List<Atom> atoms;
  final List<Bond> bonds;
  final double scale;
  final double rotationX;
  final double rotationY;
  final double rotationZ;

  MoleculePainter({
    required this.atoms,
    required this.bonds,
    required this.scale,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (atoms.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);

    final projected = <_ProjectedAtom>[];

    for (int i = 0; i < atoms.length; i++) {
      final atom = atoms[i];
      final p = _rotate(atom.x, atom.y, atom.z);

      final depth = p.z + 80.0;
      final perspective = 400.0 / depth;

      projected.add(
        _ProjectedAtom(
          index: i,
          atom: atom,
          x: center.dx + p.x * 28.0 * scale * perspective,
          y: center.dy - p.y * 28.0 * scale * perspective,
          z: p.z,
        ),
      );
    }

    final projectedByIndex = {for (final p in projected) p.index: p};

    _drawBonds(canvas, projectedByIndex);

    projected.sort((a, b) => a.z.compareTo(b.z));

    for (final p in projected) {
      _drawAtom(canvas, p);
    }
  }

  void _drawAtom(Canvas canvas, _ProjectedAtom p) {
    final baseColor = _elementColor(p.atom.element);
    final radius = _elementRadius(p.atom.element) * scale * 4.0;

    final center = Offset(p.x, p.y);

    final spherePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.85,
        colors: [
          Colors.white,
          baseColor,
          Colors.black,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, spherePaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55);

    canvas.drawCircle(
      center.translate(-radius * 0.35, -radius * 0.35),
      radius * 0.22,
      highlightPaint,
    );

    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, radius, borderPaint);
  }

  void _drawBonds(Canvas canvas, Map<int, _ProjectedAtom> projectedByIndex) {
    for (final bond in bonds) {
      final a = projectedByIndex[bond.atom1];
      final b = projectedByIndex[bond.atom2];

      if (a == null || b == null) continue;

      final p1 = Offset(a.x, a.y);
      final p2 = Offset(b.x, b.y);

      final paint = Paint()
        ..color = Colors.black
        ..strokeWidth = 6.0 * scale.clamp(0.7, 1.8)
        ..strokeCap = StrokeCap.round;

      final order = bond.order.clamp(1, 3);

      if (order == 1) {
        canvas.drawLine(p1, p2, paint);
      } else if (order == 2) {
        _drawParallelBond(canvas, p1, p2, paint, 5.0);
      } else {
        _drawTripleBond(canvas, p1, p2, paint, 5.0);
      }
    }
  }

  void _drawParallelBond(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint,
    double spacing,
  ) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final len = sqrt(dx * dx + dy * dy);

    if (len == 0) return;

    final nx = -dy / len;
    final ny = dx / len;

    final offset = Offset(nx * spacing, ny * spacing);

    canvas.drawLine(p1 + offset, p2 + offset, paint);
    canvas.drawLine(p1 - offset, p2 - offset, paint);
  }

  void _drawTripleBond(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint,
    double spacing,
  ) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final len = sqrt(dx * dx + dy * dy);

    if (len == 0) return;

    final nx = -dy / len;
    final ny = dx / len;

    final offset = Offset(nx * spacing, ny * spacing);

    canvas.drawLine(p1, p2, paint);
    canvas.drawLine(p1 + offset, p2 + offset, paint);
    canvas.drawLine(p1 - offset, p2 - offset, paint);
  }

  _Point3D _rotate(double x, double y, double z) {
    final cx = cos(rotationX);
    final sx = sin(rotationX);
    final cy = cos(rotationY);
    final sy = sin(rotationY);
    final cz = cos(rotationZ);
    final sz = sin(rotationZ);

    final y1 = y * cx - z * sx;
    final z1 = y * sx + z * cx;
    final x1 = x;

    final x2 = x1 * cy + z1 * sy;
    final z2 = -x1 * sy + z1 * cy;
    final y2 = y1;

    final x3 = x2 * cz - y2 * sz;
    final y3 = x2 * sz + y2 * cz;
    final z3 = z2;

    return _Point3D(x3, y3, z3);
  }

  Color _elementColor(String element) {
    switch (element.toUpperCase()) {
      case 'H':
        return Colors.white;
      case 'C':
        return Colors.grey.shade800;
      case 'N':
        return Colors.blueAccent;
      case 'O':
        return Colors.redAccent;
      case 'S':
        return Colors.yellowAccent;
      case 'P':
        return Colors.orangeAccent;
      case 'F':
      case 'CL':
        return Colors.greenAccent;
      case 'BR':
        return Colors.brown;
      case 'I':
        return Colors.purpleAccent;
      case 'SI':
        return Colors.orange;
      case 'PT':
        return Colors.cyanAccent;
      case 'MN':
        return Colors.purple;
      default:
        return Colors.lightGreenAccent;
    }
  }

  double _elementRadius(String element) {
    switch (element.toUpperCase()) {
      case 'H':
        return 7;
      case 'C':
        return 10;
      case 'N':
        return 11;
      case 'O':
        return 11;
      case 'S':
        return 13;
      case 'P':
        return 13;
      case 'SI':
        return 14;
      case 'PT':
        return 16;
      default:
        return 12;
    }
  }

  @override
  bool shouldRepaint(covariant MoleculePainter oldDelegate) => true;
}

class _ProjectedAtom {
  final int index;
  final Atom atom;
  final double x;
  final double y;
  final double z;

  _ProjectedAtom({
    required this.index,
    required this.atom,
    required this.x,
    required this.y,
    required this.z,
  });
}

class _Point3D {
  final double x;
  final double y;
  final double z;

  _Point3D(this.x, this.y, this.z);
}
