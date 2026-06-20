import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'structure_loader.dart';
import 'supabase_service.dart';

class SupabaseStructureFile {
  final String name;
  final String path;

  const SupabaseStructureFile({required this.name, required this.path});
}

class SupabaseCaller {
  static final SupabaseClient _client = SupabaseService.client;

  static bool _isStructureFile(String name) {
    final String lower = name.toLowerCase();

    return lower.endsWith('.sdf') ||
        lower.endsWith('.mol') ||
        lower.endsWith('.xyz') ||
        lower.endsWith('.extxyz') ||
        lower.endsWith('.cif');
  }

  static Future<List<SupabaseStructureFile>> listStructures({
    String? folder,
  }) async {
    final List<FileObject> files = await _client.storage
        .from(SupabaseService.structuresBucket)
        .list(path: folder!);

    final List<SupabaseStructureFile> structures = files
        .where((FileObject file) => _isStructureFile(file.name))
        .map(
          (FileObject file) => SupabaseStructureFile(
            name: file.name,
            path: '$folder/${file.name}',
          ),
        )
        .toList();

    structures.sort(
      (SupabaseStructureFile a, SupabaseStructureFile b) =>
          a.name.compareTo(b.name),
    );

    return structures;
  }

  static Future<List<StructureInfo>> getStructures({
    String table = 'Structures',
  }) async {
    final List<dynamic> result = await _client
        .from(table)
        .select()
        .order('name');

    return result
        .map((e) => StructureInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Molecule> loadStructure(String path) async {
    final List<int> bytes = await _client.storage
        .from(SupabaseService.structuresBucket)
        .download(path);

    final String text = utf8.decode(bytes);

    return StructureLoader.loadFromText(text: text, fileName: path);
  }

  static Future<void> addStructure({
    required String fileName,
    required Uint8List fileBytes,
    required String type,
    required String info,
  }) async {
    const String tableName = 'Structures';

    final String storagePath = '$type/$fileName';

    bool uploaded = false;

    try {
      await _client.storage
          .from(SupabaseService.structuresBucket)
          .uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: const FileOptions(upsert: false),
          );

      uploaded = true;

      await _client.from(tableName).insert({
        'name': fileName,
        'type': type,
        'info': info,
      });
    } catch (error) {
      if (uploaded) {
        await _client.storage.from(SupabaseService.structuresBucket).remove([
          storagePath,
        ]);
      }

      rethrow;
    }
  }
}
