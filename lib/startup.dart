import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/widgets/book_logo.dart';
import 'package:lanis/utils/version_label.dart';
import 'package:lanis/view/wear/wear_mode.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/widgets/offline_available_applets_section.dart';
import 'package:lanis/widgets/reset_account_page.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:lanis/utils/server_status.dart';
import 'package:lanis/view/server_status_page.dart';

/// Splash / auth progress / recoverable auth errors.
class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({super.key});

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  bool _errorSheetOpen = false;

  @override
  void initState() {
    super.initState();
    requestPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = ref.read(authControllerProvider);
      // In-app login failure may land here already in error (no phase transition).
      if (auth.phase == AuthPhase.error && auth.exception != null) {
        await _showErrorSheet(auth.exception!);
        return;
      }
      final shared = ref.read(sharedOverAccountSettingsProvider);
      final accounts = await ref.read(accountsProvider.future);
      if (!mounted) return;
      // First-time installs accept privacy on the login form instead.
      if (accounts.isNotEmpty && !isPrivacyPolicyAccepted(shared)) {
        context.go('/privacy-policy');
        return;
      }
      // Skip if loginWithAccount already drives auth — must not selectPreferred.
      await ref.read(authControllerProvider.notifier).bootstrapIfNeeded();
    });
  }

  Future<void> _showErrorSheet(LanisException exception) async {
    if (_errorSheetOpen || !mounted) return;
    _errorSheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (sheetContext) => StartupAuthErrorContent(
        exception: exception,
        onRetry: () {
          Navigator.of(sheetContext).pop();
          ref.read(authControllerProvider.notifier).retry();
        },
      ),
    );
    if (mounted) _errorSheetOpen = false;
  }

  void requestPermissions() async {
    final status = await Permission.notification.request();
    if (status.isGranted) return;
    if (status.isPermanentlyDenied && mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.notifications_outlined),
          title: Text(AppLocalizations.of(context).notifications),
          content: Text(
            AppLocalizations.of(
              context,
            ).systemPermissionForNotificationsExplained,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            TextButton(
              onPressed: () {
                AppSettings.openAppSettings();
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context).settings),
            ),
          ],
        ),
      );
    }
  }

  Widget _splashBody() {
    if (WearMode.enabled) {
      // Kompakte, runde Uhr-Ansicht
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AnimatedBookLogo(size: 96),
              const SizedBox(height: 8),
              const Text(
                'Schulportal',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 8),
              Text(
                versionLabel(),
                style: const TextStyle(fontSize: 10, color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AnimatedBookLogo(size: 150),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOut,
            builder: (context, v, child) => Opacity(opacity: v, child: child),
            child: Text(
              'Schulportal',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            versionLabel(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.phase == AuthPhase.error && next.exception != null) {
        if (previous?.phase == AuthPhase.error &&
            previous?.exception == next.exception) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showErrorSheet(next.exception!);
        });
      }
    });

    return Scaffold(body: _splashBody());
  }
}

/// Main-parity auth error chrome for the startup bottom sheet.
class StartupAuthErrorContent extends StatelessWidget {
  final LanisException exception;
  final VoidCallback onRetry;

  const StartupAuthErrorContent({
    super.key,
    required this.exception,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDown = exception is LanisDownException;
    final isOffline = exception is NoConnectionException;

    final title = isDown
        ? l10n.lanisDownError
        : isOffline
        ? l10n.noInternetConnection2
        : l10n.startupError;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: const Icon(Icons.wifi_find_outlined),
                  onPressed: () => openServerStatus(context),
                  tooltip: l10n.checkStatus,
                ),
                Icon(isOffline ? Icons.wifi_off : Icons.error, size: 48),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: onRetry,
                  tooltip: l10n.tryAgain,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(child: Text(title)),
            if (!isOffline && !isDown)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text.rich(
                  TextSpan(
                    text: l10n.startupErrorMessage,
                    children: [
                      TextSpan(
                        text:
                            '\n\n${exception.runtimeType}: ${exception.cause}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              ),
            if (exception is WrongCredentialsException)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock_reset),
                  label: Text(l10n.resetAccount),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ResetAccountPage(),
                      ),
                    );
                  },
                ),
              ),
            if (isDown)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  l10n.lanisDownErrorMessage,
                  style: Theme.of(context).textTheme.labelLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: const SingleChildScrollView(
                child: OfflineAvailableAppletsSection(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
