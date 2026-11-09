import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';

/// Öffnet die native Serverstatus-Seite (statt der Webseite im Browser).
void openServerStatus(BuildContext context) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const ServerStatusPage()));
}

enum _Level { checking, up, slow, down }

class _Service {
  final String name;
  final String description;
  final String url;

  const _Service(this.name, this.description, this.url);
}

class _Result {
  final _Level level;
  final int? milliseconds;
  final String? detail;

  const _Result(this.level, {this.milliseconds, this.detail});
}

const List<_Service> _services = [
  _Service(
    'Anmeldung',
    'login.schulportal.hessen.de',
    'https://login.schulportal.hessen.de/',
  ),
  _Service(
    'Schulportal',
    'start.schulportal.hessen.de',
    'https://start.schulportal.hessen.de/',
  ),
  _Service(
    'Nachrichten & Connect',
    'connect.schulportal.hessen.de',
    'https://connect.schulportal.hessen.de/',
  ),
];

/// Prüft die Erreichbarkeit des Schulportals nativ in der App.
class ServerStatusPage extends StatefulWidget {
  const ServerStatusPage({super.key});

  @override
  State<ServerStatusPage> createState() => _ServerStatusPageState();
}

class _ServerStatusPageState extends State<ServerStatusPage> {
  final Map<String, _Result> _results = {};
  DateTime? _checkedAt;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<_Result> _check(Dio dio, String url) async {
    final watch = Stopwatch()..start();
    try {
      final response = await dio.get<String>(url);
      watch.stop();
      final code = response.statusCode ?? 0;
      final ms = watch.elapsedMilliseconds;
      if (code == 0 || code >= 500) {
        return _Result(_Level.down, milliseconds: ms, detail: 'Fehler $code');
      }
      return _Result(ms > 2500 ? _Level.slow : _Level.up, milliseconds: ms);
    } catch (_) {
      return const _Result(_Level.down, detail: 'Nicht erreichbar');
    }
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      for (final s in _services) {
        _results[s.url] = const _Result(_Level.checking);
      }
    });
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        responseType: ResponseType.plain,
        followRedirects: true,
        validateStatus: (_) => true,
      ),
    );
    await Future.wait(
      _services.map((s) async {
        final result = await _check(dio, s.url);
        if (!mounted) return;
        setState(() => _results[s.url] = result);
      }),
    );
    dio.close();
    if (!mounted) return;
    setState(() {
      _running = false;
      _checkedAt = DateTime.now();
    });
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final results = _services.map((s) => _results[s.url]).toList();
    final checking = results.any(
      (r) => r == null || r.level == _Level.checking,
    );
    final down = results.where((r) => r?.level == _Level.down).length;
    final slow = results.where((r) => r?.level == _Level.slow).length;

    IconData summaryIcon;
    String summaryTitle;
    String summaryText;
    Color summaryBackground;
    Color summaryForeground;
    if (checking) {
      summaryIcon = Icons.sync_rounded;
      summaryTitle = 'Prüfe …';
      summaryText = 'Die Erreichbarkeit wird gerade getestet.';
      summaryBackground = scheme.surfaceContainerHighest;
      summaryForeground = scheme.onSurface;
    } else if (down > 0) {
      summaryIcon = Icons.error_rounded;
      summaryTitle = 'Störung';
      summaryText = down == _services.length
          ? 'Das Schulportal ist nicht erreichbar. Prüfe deine Internetverbindung.'
          : 'Nicht alle Dienste des Schulportals sind erreichbar.';
      summaryBackground = scheme.errorContainer;
      summaryForeground = scheme.onErrorContainer;
    } else if (slow > 0) {
      summaryIcon = Icons.warning_amber_rounded;
      summaryTitle = 'Langsam';
      summaryText = 'Das Schulportal antwortet derzeit langsam.';
      summaryBackground = scheme.tertiaryContainer;
      summaryForeground = scheme.onTertiaryContainer;
    } else {
      summaryIcon = Icons.check_circle_rounded;
      summaryTitle = 'Alles in Ordnung';
      summaryText = 'Alle Dienste des Schulportals sind erreichbar.';
      summaryBackground = scheme.primaryContainer;
      summaryForeground = scheme.onPrimaryContainer;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).serverStatus),
        actions: [
          IconButton(
            tooltip: 'Erneut prüfen',
            icon: const Icon(Icons.refresh),
            onPressed: _running ? null : _run,
          ),
        ],
        bottom: _running
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            margin: EdgeInsets.zero,
            color: summaryBackground,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(summaryIcon, size: 40, color: summaryForeground),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summaryTitle,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: summaryForeground,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summaryText,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: summaryForeground),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final service in _services) _serviceCard(context, service),
          if (_checkedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'Geprüft um ${_two(_checkedAt!.hour)}:${_two(_checkedAt!.minute)}:${_two(_checkedAt!.second)} Uhr',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _serviceCard(BuildContext context, _Service service) {
    final scheme = Theme.of(context).colorScheme;
    final result = _results[service.url] ?? const _Result(_Level.checking);

    Widget leading;
    String status;
    switch (result.level) {
      case _Level.checking:
        leading = const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 3),
        );
        status = 'Wird geprüft …';
      case _Level.up:
        leading = const Icon(Icons.check_circle_rounded, color: Colors.green);
        status = 'Erreichbar · ${result.milliseconds} ms';
      case _Level.slow:
        leading = const Icon(Icons.warning_amber_rounded, color: Colors.orange);
        status = 'Langsam · ${result.milliseconds} ms';
      case _Level.down:
        leading = Icon(Icons.cancel_rounded, color: scheme.error);
        status = result.detail ?? 'Nicht erreichbar';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: leading,
        title: Text(service.name),
        subtitle: Text('${service.description}\n$status'),
        isThreeLine: true,
      ),
    );
  }
}
