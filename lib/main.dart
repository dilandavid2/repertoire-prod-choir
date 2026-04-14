import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/library/library_screen.dart';
import 'features/editor/editor_screen.dart';
import 'features/share/share_import_screen.dart';
import 'features/setlist/setlist_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'features/setlist/join_setlist_screen.dart';

import 'features/score/score_editor_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

// 1) Inicializa Firebase (usa el archivo lib/firebase_options.dart generado por FlutterFire)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await _ensureAuth();

  await Hive.initFlutter();
  await Hive.openBox('songs');
  await Hive.openBox('songs_trash');
  await Hive.openBox('categories');
  await Hive.openBox('setlists');

  runApp(const TuCoroApp());
}

Future<void> _ensureAuth() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }
}

class TuCoroApp extends StatelessWidget {
  const TuCoroApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Repertoire',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Repertoire')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Tile(
            title: 'Biblioteca de canciones',
            subtitle: 'Ver / buscar canciones',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LibraryScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _Tile(
            title: 'Editor (ChordPro)',
            subtitle: 'Crear/editar letra con acordes [C]…',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditorScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _Tile(
            title: 'Editor de partituras',
            subtitle: 'Crear/editar partitura escrita',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ScoreEditorScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _Tile(
            title: 'Setlists',
            subtitle: 'Armar repertorio del domingo',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SetlistScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Unirme a setlist'),
            subtitle: const Text('Ingresar código'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const JoinSetlistScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _Tile(
            title: 'Importar / Compartir',
            subtitle: 'JSON / QR para compartir canciones',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ShareImportScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String title, subtitle;
  final VoidCallback onTap;
  const _Tile({required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            const Icon(Icons.music_note),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}