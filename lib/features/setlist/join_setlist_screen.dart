import 'package:flutter/material.dart';
import '../../data/repositories/setlist_cloud_repository.dart';
import 'setlist_screen.dart';
import '../../data/repositories/setlist_repository.dart';

class JoinSetlistScreen extends StatefulWidget {
  const JoinSetlistScreen({super.key});

  @override
  State<JoinSetlistScreen> createState() => _JoinSetlistScreenState();
}

class _JoinSetlistScreenState extends State<JoinSetlistScreen> {
  final TextEditingController ctrl = TextEditingController();
  final cloudRepo = SetlistCloudRepo();
  final setlistRepo = SetlistRepo();

  bool loading = false;

  Future<void> _join() async {
    final code = ctrl.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un código')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final doc = await cloudRepo.getSetlist(code);

      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El setlist no existe')),
        );
        return;
      }

      // agregar usuario actual como miembro
      await cloudRepo.addCurrentUserToMembers(code);

      // volver a leer el documento actualizado
      final updatedDoc = await cloudRepo.getSetlist(code);
      final data = updatedDoc.data()!;

      final allLocal = setlistRepo.all();

      Map<String, dynamic>? existingLocal;
      for (final s in allLocal) {
        if (s['cloudId'] == code) {
          existingLocal = s;
          break;
        }
      }

      final localSetlist = {
        'id': existingLocal?['id'],
        'cloudId': code,
        'title': data['title'] ?? 'Setlist',
        'notes': data['notes'] ?? '',
        'items': existingLocal?['items'] ?? <Map<String, dynamic>>[],
      };

      final localId = await setlistRepo.upsert(localSetlist);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SetlistEditorScreen(setlistId: localId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unirse a setlist')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Código del setlist',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loading ? null : _join,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text('Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}