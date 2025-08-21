import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class CategoryManagerScreen extends StatefulWidget {
  const CategoryManagerScreen({super.key});
  @override
  State<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends State<CategoryManagerScreen> {
  final _box = Hive.box('categories');
  final _uuid = const Uuid();
  final _ctrl = TextEditingController();

  Future<void> _add() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    final id = _uuid.v4();
    await _box.put(id, {'id': id, 'name': name});
    _ctrl.clear();
  }

  Future<void> _rename(String id, String current) async {
    final txt = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar categoría'),
        content: TextField(controller: txt, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok == true) {
      await _box.put(id, {'id': id, 'name': txt.text.trim()});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _ctrl, decoration: const InputDecoration(
                  labelText: 'Nueva categoría', border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                FilledButton(onPressed: _add, child: const Text('Agregar')),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<Box>(
              valueListenable: _box.listenable(),
              builder: (_, __, ___) {
                final items = _box.values.cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
                if (items.isEmpty) return const Center(child: Text('Sin categorías.'));
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = items[i];
                    return ListTile(
                      title: Text(c['name'] ?? ''),
                      onTap: () => _rename(c['id'], c['name'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _box.delete(c['id']),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}