import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'control_mode_screen.dart';
import '../widgets/camera_background.dart';
import '../widgets/molecule_viewer.dart';
import '../models/models.dart';
import '../services/hand_gesture_controller.dart';
import '../services/supabase_structure_loader.dart';

class ViewerScreen extends StatefulWidget {
  final ControlMode controlMode;

  const ViewerScreen({super.key, required this.controlMode});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final HandGestureController gestureController = HandGestureController();

  Molecule? molecule;
  SupabaseStructureFile? selectedStructure;

  List<SupabaseStructureFile> availableStructures = [];

  bool showCamera = true;
  bool isLoadingStructures = true;
  bool isLoadingMolecule = false;

  double moleculeScale = 1.0;
  double rotationX = 0.0;
  double rotationY = 0.0;
  double rotationZ = 0.0;

  double _scaleStart = 1.0;
  double _rotationZStart = 0.0;

  @override
  void initState() {
    super.initState();

    loadAvailableStructures();

    if (widget.controlMode == ControlMode.airGrip) {
      gestureController.onGestureUpdate = (HandGesture gesture) {
        setState(() {
          moleculeScale = gesture.scale;
          rotationX = gesture.rotationX;
          rotationY = gesture.rotationY;
          rotationZ = gesture.rotationZ;
        });
      };

      gestureController.start();
    }
  }

  Future<void> loadAvailableStructures() async {
    try {
      final List<SupabaseStructureFile> files =
          await SupabaseStructureLoader.listStructures();

      setState(() {
        availableStructures = files;
        isLoadingStructures = false;
      });
    } catch (error) {
      setState(() {
        isLoadingStructures = false;
      });

      debugPrint('Failed to list Supabase structures: $error');
    }
  }

  Future<void> loadStructure(SupabaseStructureFile file) async {
    setState(() {
      isLoadingMolecule = true;
    });

    try {
      final Molecule loadedMolecule =
          await SupabaseStructureLoader.loadStructure(file.path);

      setState(() {
        selectedStructure = file;
        molecule = loadedMolecule;

        moleculeScale = 1.0;
        rotationX = 0.0;
        rotationY = 0.0;
        rotationZ = 0.0;

        isLoadingMolecule = false;
      });
    } catch (error) {
      setState(() {
        isLoadingMolecule = false;
      });

      debugPrint('Failed to load structure: $error');
    }
  }

  void showStructureSelector() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SizedBox(
          height: 460,
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text(
                'Select Structure',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: isLoadingStructures
                    ? const Center(child: CircularProgressIndicator())
                    : availableStructures.isEmpty
                    ? const Center(
                        child: Text('No structures found in Supabase'),
                      )
                    : ListView.builder(
                        itemCount: availableStructures.length,
                        itemBuilder: (BuildContext context, int index) {
                          final SupabaseStructureFile file =
                              availableStructures[index];

                          final bool isSelected =
                              file.path == selectedStructure?.path;

                          return ListTile(
                            title: Text(file.name),
                            subtitle: Text(file.path),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : null,
                            onTap: () {
                              Navigator.pop(context);
                              loadStructure(file);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildMoleculeArea(Molecule mol) {
    final Widget viewer = MoleculeViewer(
      atoms: mol.atoms,
      bonds: mol.bonds,
      scale: moleculeScale,
      rotationX: rotationX,
      rotationY: rotationY,
      rotationZ: rotationZ,
    );

    if (widget.controlMode == ControlMode.airGrip) {
      return viewer;
    }

    return Listener(
      onPointerSignal: (PointerSignalEvent event) {
        if (event is PointerScrollEvent) {
          setState(() {
            moleculeScale = (moleculeScale - event.scrollDelta.dy * 0.001)
                .clamp(0.3, 6.0);
          });
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (ScaleStartDetails details) {
          _scaleStart = moleculeScale;
          _rotationZStart = rotationZ;
        },
        onScaleUpdate: (ScaleUpdateDetails details) {
          setState(() {
            moleculeScale = (_scaleStart * details.scale).clamp(0.3, 6.0);

            rotationZ = _rotationZStart + details.rotation;

            rotationY += details.focalPointDelta.dx * 0.01;
            rotationX += details.focalPointDelta.dy * 0.01;
          });
        },
        child: viewer,
      ),
    );
  }

  @override
  void dispose() {
    if (widget.controlMode == ControlMode.airGrip) {
      gestureController.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Molecule? mol = molecule;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (showCamera && widget.controlMode == ControlMode.airGrip)
            const CameraBackground()
          else
            const ColoredBox(color: Colors.white),

          if (isLoadingMolecule)
            const Center(child: CircularProgressIndicator())
          else if (mol == null)
            Center(
              child: Text(
                'No structure selected',
                style: TextStyle(
                  fontSize: 22,
                  color: showCamera && widget.controlMode == ControlMode.airGrip
                      ? Colors.white
                      : Colors.black,
                ),
              ),
            )
          else
            buildMoleculeArea(mol),

          Positioned(
            top: 40,
            left: 20,
            child: Text(
              mol == null
                  ? 'No structure selected'
                  : 'Atoms: ${mol.atoms.length} | Bonds: ${mol.bonds.length} | Scale: ${moleculeScale.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                color: showCamera && widget.controlMode == ControlMode.airGrip
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ),

          Positioned(
            top: 36,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: showStructureSelector,
              icon: const Icon(Icons.science),
              label: const Text('Structures'),
            ),
          ),

          Visibility(
            visible: widget.controlMode == ControlMode.airGrip,
            child: Positioned(
              top: 36,
              right: 175,
              child: IconButton.filled(
                onPressed: () async {
                  if (!showCamera) {
                    final bool ok = await gestureController
                        .requestCameraAgain();

                    if (!ok && mounted) {
                      final String? reason = gestureController
                          .getCameraPermissionStatus();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            reason == 'NotAllowedError'
                                ? 'Camera permission is blocked. Enable it from Chrome site settings, then try again.'
                                : 'Could not access camera. Please check browser camera permissions.',
                          ),
                        ),
                      );

                      return;
                    }
                  }

                  setState(() {
                    showCamera = !showCamera;
                  });
                },
                icon: Icon(showCamera ? Icons.videocam : Icons.videocam_off),
              ),
            ),
          ),

          Positioned(
            bottom: 24,
            left: 20,
            child: Text(
              widget.controlMode == ControlMode.airGrip
                  ? 'Mode: AirGrip'
                  : 'Mode: TouchOrbit',
              style: TextStyle(
                fontSize: 16,
                color: showCamera && widget.controlMode == ControlMode.airGrip
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
