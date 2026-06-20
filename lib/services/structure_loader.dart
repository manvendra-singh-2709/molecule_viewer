import 'dart:math';
import 'package:flutter/services.dart';
import '../models/models.dart';

class StructureLoader {
  static Molecule loadFromText({
    required String text,
    required String fileName,
  }) {
    final String lower = fileName.toLowerCase();

    if (lower.endsWith('.sdf') || lower.endsWith('.mol')) {
      return _parseMolOrSdf(text);
    }

    if (lower.endsWith('.xyz') || lower.endsWith('.extxyz')) {
      final List<Atom> atoms = _parseXYZ(text);
      return Molecule(atoms: atoms, bonds: _inferBonds(atoms));
    }

    if (lower.endsWith('.cif')) {
      final List<Atom> atoms = _parseCIF(text);
      return Molecule(atoms: atoms, bonds: _inferBonds(atoms));
    }

    throw Exception('Unsupported structure format: $fileName');
  }

  static Future<Molecule> loadFromAsset(String path) async {
    final String text = await rootBundle.loadString(path);

    return loadFromText(text: text, fileName: path);
  }

  static Molecule _parseMolOrSdf(String text) {
    final lines = text.split('\n');

    if (lines.length < 4) {
      throw Exception('Invalid MOL/SDF file');
    }

    final countsLine = lines[3];

    final atomCount = int.tryParse(countsLine.substring(0, 3).trim()) ?? 0;
    final bondCount = int.tryParse(countsLine.substring(3, 6).trim()) ?? 0;

    final atoms = <Atom>[];
    final bonds = <Bond>[];

    final atomStart = 4;
    final bondStart = atomStart + atomCount;

    for (int i = 0; i < atomCount; i++) {
      final line = lines[atomStart + i];

      final x = double.tryParse(line.substring(0, 10).trim()) ?? 0.0;
      final y = double.tryParse(line.substring(10, 20).trim()) ?? 0.0;
      final z = double.tryParse(line.substring(20, 30).trim()) ?? 0.0;
      final element = line.substring(31, 34).trim();

      atoms.add(Atom(element: element, x: x, y: y, z: z));
    }

    for (int i = 0; i < bondCount; i++) {
      final line = lines[bondStart + i];

      final atom1 = int.tryParse(line.substring(0, 3).trim()) ?? 0;
      final atom2 = int.tryParse(line.substring(3, 6).trim()) ?? 0;
      final order = int.tryParse(line.substring(6, 9).trim()) ?? 1;

      if (atom1 > 0 && atom2 > 0) {
        bonds.add(Bond(atom1: atom1 - 1, atom2: atom2 - 1, order: order));
      }
    }

    return Molecule(atoms: _centerAtoms(atoms), bonds: bonds);
  }

  static List<Atom> _parseXYZ(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final atoms = <Atom>[];

    for (int i = 2; i < lines.length; i++) {
      final parts = lines[i].split(RegExp(r'\s+'));
      if (parts.length < 4) continue;

      final element = _cleanElement(parts[0]);
      final x = double.tryParse(parts[1]);
      final y = double.tryParse(parts[2]);
      final z = double.tryParse(parts[3]);

      if (x == null || y == null || z == null) continue;

      atoms.add(Atom(element: element, x: x, y: y, z: z));
    }

    return _centerAtoms(atoms);
  }

  static List<Atom> _parseCIF(String text) {
    final lines = text.split('\n').map((e) => e.trim()).toList();

    double a = 1, b = 1, c = 1;

    for (final line in lines) {
      if (line.startsWith('_cell_length_a')) a = _lastNumber(line) ?? 1;
      if (line.startsWith('_cell_length_b')) b = _lastNumber(line) ?? 1;
      if (line.startsWith('_cell_length_c')) c = _lastNumber(line) ?? 1;
    }

    final atoms = <Atom>[];
    bool inAtomLoop = false;
    final headers = <String>[];

    for (final line in lines) {
      if (line == 'loop_') {
        inAtomLoop = true;
        headers.clear();
        continue;
      }

      if (!inAtomLoop) continue;

      if (line.startsWith('_atom_site')) {
        headers.add(line);
        continue;
      }

      if (headers.isNotEmpty && !line.startsWith('_') && line.isNotEmpty) {
        final parts = line.split(RegExp(r'\s+'));

        final typeIndex = headers.indexWhere(
          (h) =>
              h.contains('_atom_site_type_symbol') ||
              h.contains('_atom_site_label'),
        );

        final fxIndex = headers.indexWhere(
          (h) => h.contains('_atom_site_fract_x'),
        );
        final fyIndex = headers.indexWhere(
          (h) => h.contains('_atom_site_fract_y'),
        );
        final fzIndex = headers.indexWhere(
          (h) => h.contains('_atom_site_fract_z'),
        );

        if (typeIndex < 0 || fxIndex < 0 || fyIndex < 0 || fzIndex < 0) {
          continue;
        }

        final maxIndex = [
          typeIndex,
          fxIndex,
          fyIndex,
          fzIndex,
        ].reduce((v, e) => v > e ? v : e);

        if (parts.length <= maxIndex) continue;

        final element = _cleanElement(parts[typeIndex]);
        final fx = double.tryParse(parts[fxIndex]);
        final fy = double.tryParse(parts[fyIndex]);
        final fz = double.tryParse(parts[fzIndex]);

        if (fx == null || fy == null || fz == null) continue;

        atoms.add(Atom(element: element, x: fx * a, y: fy * b, z: fz * c));
      }
    }

    return _centerAtoms(atoms);
  }

  static List<Bond> _inferBonds(List<Atom> atoms) {
    final bonds = <Bond>[];

    for (int i = 0; i < atoms.length; i++) {
      for (int j = i + 1; j < atoms.length; j++) {
        final a = atoms[i];
        final b = atoms[j];

        final dx = a.x - b.x;
        final dy = a.y - b.y;
        final dz = a.z - b.z;
        final dist = dx * dx + dy * dy + dz * dz;

        if (_shouldBond(a, b, sqrt(dist))) {
          bonds.add(Bond(atom1: i, atom2: j, order: 1));
        }
      }
    }

    return bonds;
  }

  static bool _shouldBond(Atom a, Atom b, double dist) {
    final e1 = a.element.toUpperCase();
    final e2 = b.element.toUpperCase();
    final pair = [e1, e2]..sort();
    final key = '${pair[0]}-${pair[1]}';

    switch (key) {
      case 'O-SI':
        return dist < 1.9;
      case 'C-H':
        return dist < 1.25;
      case 'C-C':
        return dist < 1.75;
      case 'C-O':
        return dist < 1.65;
      case 'C-N':
        return dist < 1.65;
      case 'H-O':
        return dist < 1.25;
      case 'H-N':
        return dist < 1.25;
      default:
        return false;
    }
  }

  static List<Atom> _centerAtoms(List<Atom> atoms) {
    if (atoms.isEmpty) return atoms;

    final cx = atoms.map((a) => a.x).reduce((a, b) => a + b) / atoms.length;
    final cy = atoms.map((a) => a.y).reduce((a, b) => a + b) / atoms.length;
    final cz = atoms.map((a) => a.z).reduce((a, b) => a + b) / atoms.length;

    return atoms
        .map(
          (a) =>
              Atom(element: a.element, x: a.x - cx, y: a.y - cy, z: a.z - cz),
        )
        .toList();
  }

  static String _cleanElement(String raw) {
    final match = RegExp(r'[A-Z][a-z]?').firstMatch(raw);
    return match?.group(0) ?? raw;
  }

  static double? _lastNumber(String line) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 2) return null;

    return double.tryParse(parts.last.replaceAll(RegExp(r'\(.+\)'), ''));
  }
}

double mathSqrt(double x) {
  return x <= 0 ? 0 : _sqrtNewton(x);
}

double _sqrtNewton(double x) {
  double r = x;
  for (int i = 0; i < 10; i++) {
    r = 0.5 * (r + x / r);
  }
  return r;
}
