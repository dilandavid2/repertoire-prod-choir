import 'dart:io';
import 'package:flutter/material.dart';

class ImportedScoreDetailScreen extends StatefulWidget {
  final String title;
  final List<String> pages;

  const ImportedScoreDetailScreen({
    super.key,
    required this.title,
    required this.pages,
  });

  @override
  State<ImportedScoreDetailScreen> createState() =>
      _ImportedScoreDetailScreenState();
}

class _ImportedScoreDetailScreenState
    extends State<ImportedScoreDetailScreen> {
  int _page = 0;

  void _next() {
    if (_page < widget.pages.length - 1) {
      setState(() => _page++);
    }
  }

  void _prev() {
    if (_page > 0) {
      setState(() => _page--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: pages.isEmpty
          ? const Center(child: Text('Sin páginas'))
          : Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.file(
                  File(pages[_page]),
                  fit: BoxFit.fitWidth,
                  width: MediaQuery.of(context).size.width,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Página ${_page + 1} de ${pages.length}'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _prev,
                icon: const Icon(Icons.arrow_back),
              ),
              IconButton(
                onPressed: _next,
                icon: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}