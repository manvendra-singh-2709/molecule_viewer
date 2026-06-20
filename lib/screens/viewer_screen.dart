import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:molecule_viewer/global/globals.dart';

import 'control_mode_screen.dart';
import '../widgets/camera_background.dart';
import '../widgets/molecule_viewer.dart';
import '../models/models.dart';
import '../services/hand_gesture_controller.dart';
import '../services/supabase_caller.dart';
import '../services/structure_loader.dart';

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
  final List<SupabaseStructureFile> uploadedStructures = [];

  final Map<String, Molecule> uploadedMolecules = {};

  bool showCamera = true;
  bool isLoadingStructures = true;
  bool isLoadingMolecule = false;

  double moleculeScale = 1.0;
  double rotationX = 0.0;
  double rotationY = 0.0;
  double rotationZ = 0.0;

  double _scaleStart = 1.0;
  double _rotationZStart = 0.0;

  String folder = "";
  List<String> folders = [];

  @override
  void initState() {
    super.initState();

    folders = Global.folders;
    folder = folders[0];

    loadAvailableStructures(folder: folder);

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

  Future<void> loadAvailableStructures({String? folder}) async {
    try {
      final List<SupabaseStructureFile> files =
          await SupabaseCaller.listStructures(folder: folder);

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

  Future<void> pickLocalStructure() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sdf', 'mol', 'xyz', 'extxyz', 'cif'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final PlatformFile pickedFile = result.files.first;

    if (pickedFile.bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read selected file.')),
      );
      return;
    }

    final String fileName = pickedFile.name;
    final String text = utf8.decode(pickedFile.bytes!);

    try {
      final Molecule loadedMolecule = StructureLoader.loadFromText(
        text: text,
        fileName: fileName,
      );

      final SupabaseStructureFile localFile = SupabaseStructureFile(
        name: fileName,
        path: 'local/$fileName',
      );

      setState(() {
        uploadedStructures.removeWhere((file) => file.path == localFile.path);
        uploadedStructures.add(localFile);
        uploadedMolecules[localFile.path] = loadedMolecule;

        selectedStructure = localFile;
        molecule = loadedMolecule;

        moleculeScale = 1.0;
        rotationX = 0.0;
        rotationY = 0.0;
        rotationZ = 0.0;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to parse file: $error')));
    }
  }

  Future<void> loadStructure(SupabaseStructureFile file) async {
    setState(() {
      isLoadingMolecule = true;
    });

    try {
      final Molecule loadedMolecule;

      if (file.path.startsWith('local/')) {
        loadedMolecule = uploadedMolecules[file.path]!;
      } else {
        loadedMolecule = await SupabaseCaller.loadStructure(file.path);
      }

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
    final List<SupabaseStructureFile> allStructures = [
      ...uploadedStructures,
      ...availableStructures,
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SizedBox(
          height: 500,
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
                    : allStructures.isEmpty
                    ? const Center(child: Text('No structures found'))
                    : ListView.builder(
                        itemCount: allStructures.length,
                        itemBuilder: (BuildContext context, int index) {
                          final SupabaseStructureFile file =
                              allStructures[index];

                          final bool isSelected =
                              file.path == selectedStructure?.path;

                          final bool isLocal = file.path.startsWith('local/');

                          return ListTile(
                            leading: Icon(
                              isLocal
                                  ? Icons.upload_file
                                  : Icons.cloud_outlined,
                            ),
                            title: Text(file.name),
                            subtitle: Text(
                              isLocal ? 'Uploaded for this session' : file.path,
                            ),
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
    final bool darkText =
        !(showCamera && widget.controlMode == ControlMode.airGrip);

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
                  color: darkText ? Colors.black : Colors.white,
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
                color: darkText ? Colors.black : Colors.white,
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

          Positioned(
            top: 36,
            right: 175,
            child: IconButton.filled(
              onPressed: () {
                setState(() {
                  showCamera = !showCamera;
                });
              },
              icon: Icon(showCamera ? Icons.videocam : Icons.videocam_off),
            ),
          ),

          Positioned(
            top: 36,
            right: 230,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 170,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: folders.contains(folder) ? folder : null,
                      isExpanded: true,
                      hint: const Text('Folder'),
                      items: folders
                          .map(
                            (String f) => DropdownMenuItem(
                              value: f,
                              child: Text(f, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) async {
                        if (value == null) return;

                        setState(() {
                          folder = value;
                        });

                        await loadAvailableStructures(folder: value);
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                IconButton.filled(
                  onPressed: pickLocalStructure,
                  icon: const Icon(Icons.add),
                  tooltip: 'Upload structure',
                ),
              ],
            ),
          ),

          Visibility(
            visible: widget.controlMode == ControlMode.airGrip,
            child: Positioned(
              bottom: 24,
              left: 20,
              child: Text(
                widget.controlMode == ControlMode.airGrip
                    ? 'Mode: AirGrip'
                    : 'Mode: TouchOrbit',
                style: TextStyle(
                  fontSize: 16,
                  color: darkText ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
