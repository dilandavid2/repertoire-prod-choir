import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../data/repositories/song_repository.dart';
import '../../core/backup/backup_service.dart';

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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => _importFromFile(context),
              child: const Text('Importar canción desde archivo JSON'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () async {
                try {
                  await BackupService.shareBackupJson();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup exportado')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al exportar backup: $e')),
                  );
                }
              },
              child: const Text('Exportar backup completo'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Restaurar backup'),
                    content: const Text(
                      'Esto puede sobrescribir datos existentes con los del archivo seleccionado. ¿Deseas continuar?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Continuar'),
                      ),
                    ],
                  ),
                );

                if (ok != true) return;

                try {
                  await BackupService.restoreFromJsonFile();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup restaurado')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al restaurar backup: $e')),
                  );
                }
              },
              child: const Text('Restaurar backup completo'),
            ),
          ],
        ),
      ),
    );
  }
}