import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lanis/utils/logger.dart';

/// Dev-Menü: zeigt den Verlauf der App-Logs (auch im Release-Build).
class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  final ScrollController _scroll = ScrollController();

  String get _text {
    final app = logger.getHistory();
    final bg = backgroundLogger.getHistory();
    final b = StringBuffer();
    b.writeln('=== App ===');
    b.writeln(app.isEmpty ? '(noch keine Einträge)' : app);
    if (bg.isNotEmpty) {
      b.writeln();
      b.writeln('=== Hintergrund ===');
      b.writeln(bg);
    }
    return b.toString();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _toBottom();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {});
              _toBottom();
            },
          ),
          IconButton(
            tooltip: 'Kopieren',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _text));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs kopiert')),
              );
            },
          ),
          IconButton(
            tooltip: 'Leeren',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () {
              logger.clearHistory();
              backgroundLogger.clearHistory();
              setState(() {});
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.all(8),
        child: SelectableText(
          _text,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
      ),
    );
  }
}
