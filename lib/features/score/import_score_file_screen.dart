import 'package:flutter/material.dart';

import '../../data/repositories/song_repository.dart';
import 'score_file_importer.dart';

class ImportScoreFileScreen extends StatefulWidget {
  final String initialType; // image | pdf

  const ImportScoreFileScreen({
    super.key,
    this.initialType = 'image',
  });

  @override
  State<ImportScoreFileScreen> createState() => _ImportScoreFileScreenState();
}

class _ImportScoreFileScreenState extends State<ImportScoreFileScreen> {
  final SongRepo repo = SongRepo();
  final TextEditingController titleCtrl = TextEditingController();
  final importer = ScoreFileImporter();

  bool _saving = false;
  late String _selectedType; // image | pdf
  ImportedScoreAsset? _imported;

  @override
  void dispose() {
    titleCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  Future<void> _pickFile() async {
    setState(() => _saving = true);

    try {
      final result = _selectedType == 'image'
          ? await importer.pickImages()
          : await importer.pickPdf();

      if (!mounted) return;

      setState(() {
        _imported = result;
        if ((titleCtrl.text).trim().isEmpty && result != null) {
          titleCtrl.text = result.originalName;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _save() async {
    if (_imported == null) return;
    if (titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ponle un título')),
      );
      return;
    }

    final song = <String, dynamic>{
      'title': titleCtrl.text.trim(),
      'baseKey': 'C',
      'mode': _imported!.mode,
      'bodyChordPro': '',
      'imagePages': _imported!.mode == 'score_image' ? _imported!.pages : <String>[],
      'pdfPages': _imported!.mode == 'score_pdf' ? _imported!.pages : <String>[],
    };

    await repo.upsert(song);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar partitura externa'),
        actions: [
          IconButton(
            onPressed: _imported != null ? _save : null,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Tipo',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'image', child: Text('Imágenes')),
              DropdownMenuItem(value: 'pdf', child: Text('PDF')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _selectedType = v;
                _imported = null;
              });
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _pickFile,
            icon: const Icon(Icons.attach_file),
            label: Text(_saving ? 'Importando...' : 'Seleccionar archivo(s)'),
          ),
          const SizedBox(height: 16),
          if (_imported != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Importado: ${_imported!.pages.length} página(s)\nModo: ${_imported!.mode}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}