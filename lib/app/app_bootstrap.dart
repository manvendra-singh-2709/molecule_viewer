import 'package:flutter/material.dart';
import 'package:molecule_viewer/global/globals.dart';

import '../screens/control_mode_screen.dart';
import '../services/api_service.dart';

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool isReady = false;
  String status = 'Starting Molecule Viewer...';

  @override
  void initState() {
    super.initState();
    boot();
  }

  Future<void> boot() async {
    setState(() {
      status = 'Loading structures...';
    });

    await Global.getFolders();

    await ApiService.instance.initializeAppServices(
      preloadMediaPipe: false,
    );

    if (!mounted) return;

    setState(() {
      isReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isReady) {
      return const ControlModeScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.science, size: 64, color: Colors.white),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(status, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}