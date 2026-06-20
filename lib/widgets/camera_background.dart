import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraBackground extends StatefulWidget {
  const CameraBackground({super.key});

  @override
  State<CameraBackground> createState() => _CameraBackgroundState();
}

class _CameraBackgroundState extends State<CameraBackground> {
  CameraController? controller;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    final List<CameraDescription> cameras = await availableCameras();

    if (cameras.isEmpty) return;

    controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller!.initialize();

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: controller!.value.aspectRatio,
        child: CameraPreview(controller!),
      ),
    );
  }
}