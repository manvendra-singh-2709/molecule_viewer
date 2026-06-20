import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'supabase_caller.dart';
import 'hand_gesture_controller.dart';

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  List<SupabaseStructureFile> structures = [];
  bool mediaPipeReady = false;
  bool structuresReady = false;

  Future<void> initializeAppServices({
    required bool preloadMediaPipe,
  }) async {
    await Future.wait([
      _loadStructures(folder: "Organics"),
      if (preloadMediaPipe && kIsWeb) _loadMediaPipe(),
    ]);
  }

  Future<void> _loadStructures({String? folder}) async {
    try {
      structures = await SupabaseCaller.listStructures(folder: folder);
      structuresReady = true;
    } catch (e) {
      debugPrint('Failed to preload Supabase structures: $e');
      structuresReady = false;
    }
  }

  Future<void> _loadMediaPipe() async {
    try {
      final HandGestureController controller = HandGestureController();
      final bool ok = await controller.initializeOnly();
      mediaPipeReady = ok;
      controller.dispose();
    } catch (e) {
      debugPrint('Failed to preload MediaPipe: $e');
      mediaPipeReady = false;
    }
  }

  Future<Molecule> loadMolecule(SupabaseStructureFile file) {
    return SupabaseCaller.loadStructure(file.path);
  }
}