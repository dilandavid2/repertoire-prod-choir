import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/repositories/song_repository.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = SongRepo();
    return Scaffold(
      appBar: AppBar(title: const Text('Papelera')),
      body: ValueListenableBuilder<Box>(
        valueListenable: repo.listenTrash(),
        builder: (_, __, ___) {
          final items = repo.allTrashed();
          if (items.isEmpty) return const Center(child: Text('Vacío.'));
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = items[i];
              return ListTile(
                title: Text(s['title'] ?? '(sin título)'),
                subtitle: const Text('En papelera'),
                trailing: Wrap(spacing: 8, children: [
                  IconButton(
                    tooltip: 'Restaurar',
                    icon: const Icon(Icons.settings_backup_restore),
                    onPressed: () => repo.restore(s['id']),
                  ),
                  IconButton(
                    tooltip: 'Eliminar definitivamente',
                    icon: const Icon(Icons.delete_forever_outlined),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Eliminar definitivamente'),
                          content: Text('¿Eliminar "${s['title'] ?? 'esta canción'}" para siempre?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
                          ],
                        ),
                      );
                      if (ok == true) await repo.deleteForever(s['id']);
                    },
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}