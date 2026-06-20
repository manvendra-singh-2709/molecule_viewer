import 'dart:developer';

import 'package:flutter/material.dart';

import '../global/globals.dart';
import '../models/models.dart';
import '../services/supabase_caller.dart';

class DeleteStructureScreen extends StatefulWidget {
  const DeleteStructureScreen({super.key});

  @override
  State<DeleteStructureScreen> createState() => _DeleteStructureScreenState();
}

class _DeleteStructureScreenState extends State<DeleteStructureScreen> {
  List<String> folders = [];
  String? selectedFolder;

  List<StructureInfo> structures = [];

  bool isLoading = true;
  bool isDeleting = false;

  @override
  void initState() {
    super.initState();
    loadFolders();
  }

  Future<void> loadFolders() async {
    final loadedFolders = await Global.getFolders();

    if (!mounted) return;

    setState(() {
      folders = loadedFolders;
      selectedFolder = folders.isNotEmpty ? folders.first : null;
    });

    log("Del loaded: $folders");

    if (selectedFolder != null) {
      await loadStructures();
    }
  }

  Future<void> loadStructures() async {
    final String? folder = selectedFolder;
    if (folder == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final List<StructureInfo> data = await SupabaseCaller.getStructuresByType(
        type: folder,
      );

      setState(() {
        structures = data;
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load structures: $error')),
      );
    }
  }

  Future<void> confirmDelete(StructureInfo structure) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete structure?'),
          content: Text(
            'This will delete "${structure.name}" from both Supabase table and storage.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    setState(() {
      isDeleting = true;
    });

    try {
      await SupabaseCaller.deleteStructureEverywhere(structure: structure);

      await loadStructures();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Structure deleted.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed. Restore attempted. Error: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasFolders = folders.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Delete Structure')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (!hasFolders)
                  const Expanded(
                    child: Center(child: Text('No folders/types found.')),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    value: selectedFolder,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Folder / Type',
                      border: OutlineInputBorder(),
                    ),
                    items: folders
                        .map(
                          (String folder) => DropdownMenuItem<String>(
                            value: folder,
                            child: Text(folder),
                          ),
                        )
                        .toList(),
                    onChanged: isDeleting
                        ? null
                        : (String? value) async {
                            if (value == null) return;

                            setState(() {
                              selectedFolder = value;
                            });

                            await loadStructures();
                          },
                  ),

                  const SizedBox(height: 20),

                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : structures.isEmpty
                        ? const Center(
                            child: Text('No structures in this folder.'),
                          )
                        : ListView.separated(
                            itemCount: structures.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final StructureInfo structure = structures[index];

                              return ListTile(
                                title: Text(structure.name),
                                subtitle: Text(
                                  '${structure.type}\n${structure.info}',
                                ),
                                isThreeLine: true,
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  color: Colors.redAccent,
                                  onPressed: isDeleting
                                      ? null
                                      : () => confirmDelete(structure),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
