import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../data/repositories/song_repository.dart';

class ShareImportScreen extends StatelessWidget {
  const ShareImportScreen({super.key});

  Future<void> _importFromFile(BuildContext context) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    if (r == null || r.files.single.path == null) return;
    final content = await File(r.files.single.path!).readAsString();
    final root = jsonDecode(content);
    Map<String, dynamic> payload;
    if (root is Map && root['schema'] == 'tu_coro.song') {
      payload = Map<String, dynamic>.from(root['payload']);
    } else {
      payload = Map<String, dynamic>.from(root);
    }
    await SongRepo().upsert({
      'id': payload['id'],
      'title': payload['title'],
      'baseKey': payload['baseKey'] ?? 'C',
      'bodyChordPro': payload['bodyChordPro'] ?? '',
    });
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Canción importada')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar / Compartir')),
      body: Center(
        child: FilledButton(
          onPressed: () => _importFromFile(context),
          child: const Text('Importar canción desde archivo JSON'),
        ),
      ),
    );
  }
}