import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/view/wear/wear_mode.dart';
import 'package:lanis/widgets/book_logo.dart';
import 'package:liblanis/liblanis.dart';
import 'package:local_auth/local_auth.dart';

const String appLockKey = 'app-lock';

/// Fragt Fingerabdruck/Gesicht bzw. Geräte-PIN ab. `true` bei Erfolg.
Future<bool> authenticateDevice(String reason) async {
  try {
    final auth = LocalAuthentication();
    if (!await auth.isDeviceSupported()) return false;
    return await auth.authenticate(localizedReason: reason);
  } catch (_) {
    return false;
  }
}

/// Sperrt die App beim Wiederöffnen, wenn die App-Sperre aktiv ist.
class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _busy = false;
  DateTime? _pausedAt;

  bool get _enabled {
    if (WearMode.enabled) return false;
    try {
      return ref.read(sharedOverAccountSettingsProvider).getString(appLockKey) ==
          '1';
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_enabled) {
      _locked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_busy) return;
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // Kurze Unterbrechungen (Teilen-Dialog, Dateiauswahl) sperren nicht.
      final away = _pausedAt == null
          ? Duration.zero
          : DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      if (!_locked && _enabled && away > const Duration(seconds: 30)) {
        setState(() => _locked = true);
      }
      if (_locked) _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_busy) return;
    _busy = true;
    final ok = await authenticateDevice('Schulportal entsperren');
    // kurz warten, damit das Schließen des Dialogs nicht als Pause zählt
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _busy = false;
    if (mounted && ok) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AnimatedBookLogo(size: 110),
                    const SizedBox(height: 16),
                    Text(
                      'Schulportal ist gesperrt',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _unlock,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('Entsperren'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
