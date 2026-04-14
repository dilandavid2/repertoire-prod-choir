import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../editor/editor_screen.dart';
import 'category_manager_screen.dart';
import 'trash_screen.dart';
import '../../data/repositories/song_repository.dart';

import '../score/score_editor_screen.dart';

import '../score/import_score_file_screen.dart';

import '../score/imported_score_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String? _selectedCategoryId;

  // 🔎 búsqueda
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final SongRepo repo = SongRepo();
  String _query = '';
  bool _showSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = true;
    });
    // Enfoca el campo después de un frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  Future<void> _showCreateMenu() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: const Text('Nueva canción'),
                  subtitle: const Text('Letra y acordes'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      this.context,
                      MaterialPageRoute(builder: (_) => const EditorScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.music_note),
                  title: const Text('Nueva partitura editable'),
                  subtitle: const Text('Editor interno de partituras'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      this.context,
                      MaterialPageRoute(
                        builder: (_) => const ScoreEditorScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Importar partitura por imagen'),
                  subtitle: const Text('Una o varias páginas'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      this.context,
                      MaterialPageRoute(
                        builder: (_) => const ImportScoreFileScreen(
                          initialType: 'image',
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: const Text('Importar partitura por PDF'),
                  subtitle: const Text('PDF convertido en páginas'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      this.context,
                      MaterialPageRoute(
                        builder: (_) => const ImportScoreFileScreen(
                          initialType: 'pdf',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final songsBox = Hive.box('songs');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca'),
        actions: [
          // Papelera
          IconButton(
            tooltip: 'Papelera',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TrashScreen()),
            ),
            icon: const Icon(Icons.delete_outline),
          ),
          // Buscar
          IconButton(
            tooltip: 'Buscar',
            onPressed: _toggleSearch,
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateMenu,
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ▸ Barra de búsqueda (colapsable)
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar por título, letra o categoría…',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _query.isEmpty
                      ? IconButton(
                          tooltip: 'Cerrar búsqueda',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() => _showSearch = false);
                            _clearSearch();
                          },
                        )
                      : IconButton(
                          tooltip: 'Limpiar',
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                        ),
                ),
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
              ),
            ),

          // ▸ Barra de filtros por categoría
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: _CategoryFilterBar(
              selectedId: _selectedCategoryId,
              onChanged: (id) => setState(() => _selectedCategoryId = id),
            ),
          ),

          // ▸ Lista
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: songsBox.listenable(),
              builder: (_, Box box, __) {
                // Conversión segura
                final all = box.values
                    .map<Map<String, dynamic>>(
                      (e) => Map<String, dynamic>.from(e as Map),
                    )
                    .toList();

                // Filtro por categoría (si hay)
                final byCat = _selectedCategoryId == null
                    ? all
                    : all.where((s) {
                        final ids = (s['categoryIds'] as List? ?? const [])
                            .whereType<String>()
                            .toList();
                        return ids.contains(_selectedCategoryId);
                      }).toList();

                // Filtro por búsqueda (título, letra, categorías)
                final filtered = _query.isEmpty
                    ? byCat
                    : byCat.where((s) {
                        final title = (s['title'] ?? '').toString().toLowerCase();
                        final body = (s['bodyChordPro'] ?? '').toString().toLowerCase();
                        final catNames = ((s['songCategoryNames'] ?? []) as List)
                            .whereType<String>()
                            .join(',')
                            .toLowerCase();
                        return title.contains(_query) ||
                            body.contains(_query) ||
                            catNames.contains(_query);
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No hay canciones. Toca + para crear.'),
                  );
                }

                // Orden alfabético por título
                filtered.sort((a, b) =>
                    (a['title'] ?? '').toString().toLowerCase().compareTo(
                          (b['title'] ?? '').toString().toLowerCase(),
                        ));

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = filtered[i];

                    final title = s['title'] as String? ?? '(sin título)';
                    final baseKey = s['baseKey'] as String? ?? '-';

                    // Nombres de categorías (guardados desde el editor)
                    final catNames = (s['songCategoryNames'] as List?)
                            ?.whereType<String>()
                            .toList() ??
                        const <String>[];

                    final mode = (s['mode'] ?? 'chordpro').toString();
                    String tipo;
                    switch (mode) {
                      case 'score':
                        tipo = 'Partitura editable';
                        break;
                      case 'score_image':
                        tipo = 'Partitura por imagen';
                        break;
                      case 'score_pdf':
                        tipo = 'Partitura por PDF';
                        break;
                      default:
                        tipo = 'Letra/Acordes';
                    }

                    return ListTile(
                      title: Text(title),
                      // 👉 Sin IDs raros: Tono + categorías (si hay)
                      subtitle: Text(
                        'Tono: $baseKey'
                            '${catNames.isNotEmpty ? '  ·  ${catNames.join(', ')}' : ''}'
                            '  ·  Tipo: $tipo',
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) {
                            final mode = (s['mode'] ?? 'chordpro').toString();
                            final title = s['title'] as String? ?? '(sin título)';

                            if (mode == 'score') {
                              return ScoreEditorScreen(
                                songId: s['id'] as String?,
                              );
                            }

                            if (mode == 'score_image') {
                              return ImportedScoreDetailScreen(
                                title: title,
                                pages: (s['imagePages'] as List?)?.cast<String>() ?? [],
                              );
                            }

                            if (mode == 'score_pdf') {
                              return ImportedScoreDetailScreen(
                                title: title,
                                pages: (s['pdfPages'] as List?)?.cast<String>() ?? [],
                              );
                            }

                            return EditorScreen(
                              songId: s['id'] as String?,
                            );
                          },
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'Mover a papelera',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Mover a papelera'),
                                  content: Text(
                                    '¿Enviar "${s['title'] ?? 'esta canción'}" a la papelera?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Mover'),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;
                          if (!ok) return;

                          await repo.trash(s['id']);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Movida a la papelera'),
                              ),
                            );
                          }
                        },
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

/// Barra horizontal con chips para filtrar por categoría + acceso al gestor
class _CategoryFilterBar extends StatefulWidget {
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  const _CategoryFilterBar({
    required this.selectedId,
    required this.onChanged,
  });

  @override
  State<_CategoryFilterBar> createState() => _CategoryFilterBarState();
}

class _CategoryFilterBarState extends State<_CategoryFilterBar> {
  final Box _catBox = Hive.box('categories');

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _catBox.listenable(),
      builder: (_, __, ___) {
        // Conversión segura
        final cats = _catBox.values
            .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map),
            )
            .toList();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Todas'),
                selected: widget.selectedId == null,
                onSelected: (_) => widget.onChanged(null),
              ),
              const SizedBox(width: 8),
              ...cats.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c['name'] as String? ?? ''),
                    selected: widget.selectedId == c['id'],
                    onSelected: (_) => widget.onChanged(c['id'] as String?),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Categorías'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CategoryManagerScreen(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}