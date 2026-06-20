import 'package:molecule_viewer/models/models.dart';
import 'package:molecule_viewer/services/supabase_caller.dart';

class Global {
  static List<String> folders = [];

  static Future<List<String>> getFolders() async {
    final List<StructureInfo> data =
        await SupabaseCaller.getStructures();

    folders = data.map((StructureInfo item) => item.type).toSet().toList()
      ..sort();

    return folders;
  }
}
