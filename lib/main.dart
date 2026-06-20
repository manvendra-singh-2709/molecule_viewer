import 'package:flutter/material.dart';

import 'app/app_bootstrap.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.init();

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
      home: const AppBootstrap(),
    );
  }
}