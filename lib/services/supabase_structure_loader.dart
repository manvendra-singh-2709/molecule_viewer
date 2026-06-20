import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'structure_loader.dart';
import 'supabase_service.dart';

class SupabaseStructureFile {
  final String name;
  final String path;

  const SupabaseStructureFile({
    required this.name,
    required this.path,
  });
}

class SupabaseStructureLoader {
  static final SupabaseClient _client = SupabaseService.client;

  static bool _isStructureFile(String name) {
    final String lower = name.toLowerCase();

    return lower.endsWith('.sdf') ||
        lower.endsWith('.mol') ||
        lower.endsWith('.xyz') ||
        lower.endsWith('.extxyz') ||
        lower.endsWith('.cif');
  }

  static Future<List<SupabaseStructureFile>> listStructures() async {
    final List<FileObject> files = await _client.storage
        .from(SupabaseService.structuresBucket)
        .list(path: 'Organics');
      
    final List<SupabaseStructureFile> structures = files
        .where((FileObject file) => _isStructureFile(file.name))
        .map(
          (FileObject file) => SupabaseStructureFile(
            name: file.name,
            path: 'Organics/${file.name}',
          ),
        )
        .toList();

    structures.sort(
      (SupabaseStructureFile a, SupabaseStructureFile b) =>
          a.name.compareTo(b.name),
    );

    return structures;
  }

  static Future<Molecule> loadStructure(String path) async {
    final List<int> bytes = await _client.storage
        .from(SupabaseService.structuresBucket)
        .download(path);

    final String text = utf8.decode(bytes);

    return StructureLoader.loadFromText(
      text: text,
      fileName: path,
    );
  }
}