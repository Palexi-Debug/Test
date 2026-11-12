import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/home_page.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/utils/watch_sync.dart';
import 'package:lanis/view/login/auth.dart';
import 'package:lanis/widgets/book_logo.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

/// Login auf der Uhr: wartet auf die Zugangsdaten vom Handy
/// (Handy: Einstellungen > "An Uhr senden"). Manuelles Anmelden bleibt möglich.
class WearLoginPage extends ConsumerStatefulWidget {
  const WearLoginPage({super.key});

  @override
  ConsumerState<WearLoginPage> createState() => _WearLoginPageState();
}

class _WearLoginPageState extends ConsumerState<WearLoginPage> {
  final WatchConnectivity _watch = WatchConnectivity();
  final List<StreamSubscription> _subs = [];
  bool _busy = false;
  String _status = 'Warte auf das Handy …';

  @override
  void initState() {
    super.initState();
    _subs.add(_watch.messageStream.listen(_onData));
    _subs.add(_watch.contextStream.listen(_onData));
    _watch.receivedApplicationContexts.then((list) {
      for (final m in list) {
        _onData(m);
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _onData(Map<String, dynamic> m) async {
    if (_busy || m['kind'] != watchLoginKind) return;
    _busy = true;
    if (mounted) setState(() => _status = 'Melde an …');
    try {
      final shared = ref.read(sharedOverAccountSettingsProvider);
      acceptPrivacyPolicy(shared);

      final schoolId = (m['school'] as num).toInt();
      final username = m['user'] as String;
      final password = m['pass'] as String;
      final typeName = m['type'] as String?;
      AccountType? type;
      if (typeName != null) {
        for (final t in AccountType.values) {
          if (t.name == typeName) type = t;
        }
      }

      final accounts = await ref.read(accountsProvider.future);
      int? existing;
      for (final a in accounts) {
        if (a.schoolID == schoolId && a.username == username) {
          existing = a.localId;
        }
      }
      final id = existing ??
          await ref
              .read(accountsProvider.notifier)
              .add(
                schoolId: schoolId,
                schoolName: (m['schoolName'] as String?) ?? '',
                username: username,
                password: password,
                accountType: type,
              );
      final ok = await ref
          .read(authControllerProvider.notifier)
          .loginWithAccount(id, removeAccountOnFailure: existing == null);
      await _watch.sendMessage({'kind': 'ack', 'ok': ok});
      if (!mounted) return;
      if (ok) {
        context.go(firstSupportedHomePath(ref));
      } else {
        setState(() => _status = 'Anmeldung fehlgeschlagen');
        _busy = false;
      }
    } catch (e) {
      try {
        await _watch.sendMessage({'kind': 'ack', 'ok': false, 'error': '$e'});
      } catch (_) {}
      if (mounted) setState(() => _status = 'Fehler bei der Anmeldung');
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AnimatedBookLogo(size: 64),
              const SizedBox(height: 8),
              const Text(
                'Mit Handy verbinden',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Handy: Einstellungen > "An Uhr senden"',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                _status,
                style: const TextStyle(fontSize: 12, color: Colors.amber),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            body: LoginForm(showBackButton: true),
                          ),
                        ),
                      ),
                child: const Text('Manuell anmelden'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
