import 'package:flutter/material.dart';
import 'package:molecule_viewer/global/globals.dart';
import 'package:molecule_viewer/screens/add_structure_screen.dart';
import 'package:molecule_viewer/screens/delete_structure_screen.dart';
import 'package:url_strategy/url_strategy.dart';

import 'app/app_bootstrap.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  setPathUrlStrategy();

  await SupabaseService.init();
  await Global.getFolders();

  runApp(const MoleculeViewerApp());
}

class MoleculeViewerApp extends StatelessWidget {
  const MoleculeViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Molecule Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      routes: {
        '/': (_) => const AppBootstrap(),
        '/add': (_) => const AddStructureScreen(),
        '/delete': (_) => const DeleteStructureScreen(),
      },
      initialRoute: '/',
    );
  }
}