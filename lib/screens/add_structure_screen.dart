import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/supabase_caller.dart';

class AddStructureScreen extends StatefulWidget {
  const AddStructureScreen({super.key});

  @override
  State<AddStructureScreen> createState() => _AddStructureScreenState();
}

class _AddStructureScreenState extends State<AddStructureScreen> {
  final TextEditingController infoController = TextEditingController();

  final List<String> types = const [
    'Organics',
    'Amorphous',
    'Crystalline',
    'Liquid',
    'Gas',
    'Protien',
  ];

  String selectedType = 'Organics';

  PlatformFile? pickedFile;
  Uint8List? pickedBytes;

  bool isUploading = false;

  Future<void> pickStructureFile() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sdf', 'mol', 'xyz', 'extxyz', 'cif'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      pickedFile = result.files.first;
      pickedBytes = result.files.first.bytes;
    });
  }

  Future<void> submit() async {
    if (pickedFile == null || pickedBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a structure file.')),
      );
      return;
    }

    setState(() {
      isUploading = true;
    });

    try {
      await SupabaseCaller.addStructure(
        fileName: pickedFile!.name,
        fileBytes: pickedBytes!,
        type: selectedType,
        info: infoController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Structure added successfully.')),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    infoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? fileName = pickedFile?.name;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Structure'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type / Folder',
                    border: OutlineInputBorder(),
                  ),
                  items: types
                      .map(
                        (String type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        ),
                      )
                      .toList(),
                  onChanged: isUploading
                      ? null
                      : (String? value) {
                          if (value == null) return;
                          setState(() {
                            selectedType = value;
                          });
                        },
                ),

                const SizedBox(height: 18),

                TextField(
                  controller: infoController,
                  enabled: !isUploading,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Info',
                    hintText: 'Add structure details here...',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 18),

                OutlinedButton.icon(
                  onPressed: isUploading ? null : pickStructureFile,
                  icon: const Icon(Icons.upload_file),
                  label: Text(fileName ?? 'Choose structure file'),
                ),

                if (fileName != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Will save as: $selectedType/$fileName',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],

                const Spacer(),

                FilledButton.icon(
                  onPressed: isUploading ? null : submit,
                  icon: isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(isUploading ? 'Adding...' : 'Add Structure'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}