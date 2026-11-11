import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:lanis/utils/updater.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/view/secret/secret_page.dart';

/// Fragt den Nutzer, ob das Update installiert werden soll.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
  return showDialog<void>(
    context: context,
    builder: (_) => _UpdateDialog(info),
  );
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const _UpdateDialog(this.info);

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    final err = await downloadAndInstall(widget.info, (p) {
      if (mounted) setState(() => _progress = p);
    });
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _progress = null;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloading = _progress != null;
    return AlertDialog(
      icon: const Icon(Icons.system_update_rounded, size: 40),
      title: Text('Update auf Build ${widget.info.build}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Aktuell installiert: Build $currentBuildId'),
          if (widget.info.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Was ist neu', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(child: Text(widget.info.notes.trim())),
            ),
          ],
          if (downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: downloading ? null : () => Navigator.pop(context),
          child: const Text('Später'),
        ),
        FilledButton(
          onPressed: downloading ? null : _install,
          child: const Text('Installieren'),
        ),
      ],
    );
  }
}

/// Seite "Version": Build, Update-Suche und Hinweis auf Lanis Mobile.
class VersionPage extends StatefulWidget {
  const VersionPage({super.key});

  @override
  State<VersionPage> createState() => _VersionPageState();
}

class _VersionPageState extends State<VersionPage> {
  String _version = '';
  bool _checking = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (mounted) setState(() => _version = '${p.version} (${p.buildNumber})');
    });
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _status = null;
    });
    final res = await checkForUpdate();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _status = switch (res.result) {
        UpdateCheckResult.upToDate => 'Du hast die neueste Version.',
        UpdateCheckResult.failed =>
          'Update-Suche nicht möglich (offline oder noch kein Release).',
        UpdateCheckResult.newer => 'Build ${res.info!.build} ist verfügbar.',
      };
    });
    if (res.result == UpdateCheckResult.newer) {
      await showUpdateDialog(context, res.info!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Version')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 48,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text('Schulportal', style: text.headlineSmall)),
          Center(
            child: SecretBuildTap(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Build $currentBuildId',
                  style: text.titleMedium?.copyWith(color: scheme.primary),
                ),
              ),
            ),
          ),
          if (_version.isNotEmpty)
            Center(
              child: Text(
                'Version $_version',
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Updates', style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    _status ?? 'Neue Builds werden hier automatisch angeboten.',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _checking ? null : _check,
                    icon: _checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: const Text('Nach Updates suchen'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Basiert auf Lanis Mobile',
                    style: text.titleMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Diese App ist eine eigene Oberfläche für die Philipp-Reis-Schule. '
                    'Sie basiert auf dem freien Projekt Lanis Mobile (GPLv3) und '
                    'nutzt dessen Anbindung an das Schulportal Hessen. '
                    'Danke an alle Mitwirkenden!',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.groups_rounded),
                  title: const Text('Mitwirkende, Links, Lizenzen'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(SettingsDeepLinks.about),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
