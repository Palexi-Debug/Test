import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/home_page.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/utils/logger.dart';
import 'package:lanis/utils/glitchtip.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:lanis/view/secret/secret_page.dart';

class LoginForm extends ConsumerStatefulWidget {
  final bool showBackButton;
  const LoginForm({required this.showBackButton, super.key});

  @override
  ConsumerState<LoginForm> createState() => LoginFormState();
}

class LoginFormState extends ConsumerState<LoginForm> {
  static const double padding = 10.0;

  final _formKey = GlobalKey<FormState>();

  // Diese App ist fest auf eine Schule eingestellt.
  static const String fixedSchoolId = '6110';
  static const String fixedSchoolName = 'Philipp-Reis-Schule';
  // Build-Nummer aus GitHub Actions, damit man die installierte Version erkennt
  static const String buildId = String.fromEnvironment(
    'BUILD_ID',
    defaultValue: 'dev',
  );

  TextEditingController schoolIDController = TextEditingController(
    text: fixedSchoolId,
  );
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool dseAgree = true; // Zustimmungs-Checkboxen entfernt
  bool errorReportingAgree = false;
  String selectedSchoolName = fixedSchoolName;

  @override
  void initState() {
    super.initState();
    // Mirror the device-wide GlitchTip choice when adding another account.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final shared = ref.read(sharedOverAccountSettingsProvider);
      setState(() {
        errorReportingAgree = isGlitchTipEnabled(shared);
      });
    });
  }

  void login(String username, String password, String schoolID) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).logInTitle),
        content: const Center(
          heightFactor: 1.2,
          child: CircularProgressIndicator(),
        ),
      ),
    );
    try {
      final schoolId = int.parse(schoolID);
      final accounts = await ref.read(accountsProvider.future);
      if (accounts.any(
        (a) => a.schoolID == schoolId && a.username == username,
      )) {
        throw AccountAlreadyExistsException();
      }

      // Login checkbox is the first-time privacy acceptance for new accounts.
      final shared = ref.read(sharedOverAccountSettingsProvider);
      acceptPrivacyPolicy(shared);
      setGlitchTipEnabled(shared, errorReportingAgree);

      final config = ref.read(lanisConfigProvider);
      await LanisSession.getLoginURL(
        ClearTextAccount(
          localId: -1,
          schoolID: schoolId,
          username: username,
          password: password,
          schoolName: "",
        ),
        config,
      );

      final newID = await ref
          .read(accountsProvider.notifier)
          .add(
            schoolId: schoolId,
            username: username,
            password: password,
            schoolName: selectedSchoolName,
          );
      final ok = await ref
          .read(authControllerProvider.notifier)
          .loginWithAccount(newID, removeAccountOnFailure: true);
      if (!mounted) return;
      Navigator.pop(context); // pop dialog
      if (ok) {
        context.go(firstSupportedHomePath(ref));
        return;
      }
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      final cause =
          auth.exception?.cause ?? AppLocalizations.of(context).unknownError;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context).error),
          content: Text(cause),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (ex, s) {
      logger.e(ex, stackTrace: s);

      String cause = "";
      if (ex is LanisException) {
        cause = ex.cause;
      } else {
        if (mounted) {
          cause = AppLocalizations.of(context).unknownError;
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // pop dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context).error),
          content: Text(cause),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    schoolIDController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _LoginBackground()),
        if (widget.showBackButton)
          Padding(
            padding: EdgeInsets.only(right: 32, top: 32),
            child: IconButton(
              onPressed: () {
                // Welcome uses go('/login') (no stack); account switcher uses push.
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/login');
                }
              },
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(padding),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 550),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: padding),
                          Center(
                            child: Column(
                              children: [
                                const Icon(Icons.person, size: 70),
                                Text(
                                  AppLocalizations.of(context).logIn,
                                  style: const TextStyle(fontSize: 35),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: padding * 5),
                          Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              leading: const Icon(Icons.school),
                              title: const Text(fixedSchoolName),
                              subtitle: SecretBuildTap(
                                child: Text(
                                  'Schulportal Hessen · ID $fixedSchoolId · Build $buildId',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: padding),
                          TextFormField(
                            controller: usernameController,
                            enabled: schoolIDController.text != "",
                            autofillHints: [AutofillHints.username],
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(
                                context,
                              ).authUsernameHint,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppLocalizations.of(
                                  context,
                                ).authValidationError;
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: padding),
                          TextFormField(
                            controller: passwordController,
                            enabled: schoolIDController.text.isNotEmpty,
                            autofillHints: [AutofillHints.password],
                            autocorrect: false,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(
                                context,
                              ).authPasswordHint,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppLocalizations.of(
                                  context,
                                ).authValidationError;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: padding),
                          FilledButton(
                            onPressed: dseAgree
                                ? () {
                                    if (_formKey.currentState!.validate()) {
                                      login(
                                        usernameController.text.toLowerCase(),
                                        passwordController.text,
                                        schoolIDController.text,
                                      );
                                    }
                                  }
                                : null,
                            child: Text(AppLocalizations.of(context).logIn),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: schoolIDController.text.isNotEmpty
                                    ? () => safeLaunchUrl(
                                        Uri.parse(
                                          "https://start.schulportal.hessen.de/benutzerverwaltung.php?a=userPWreminder&i=${schoolIDController.text}",
                                        ),
                                        context: context,
                                      )
                                    : null,
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  ).authResetPassword,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


/// Hintergrund des Logins: Foto der Schule (Tag im hellen, Nacht im dunklen
/// Modus). Ohne Internet wird eine mitgelieferte Zeichnung gezeigt.
class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fallback = Image.asset(
      dark ? 'assets/login_night.jpg' : 'assets/login_day.jpg',
      fit: BoxFit.cover,
    );
    final photo = Image.network(
      'https://startcache.schulportal.hessen.de/exporteur.php?a=schoolbg&i=${LoginFormState.fixedSchoolId}&s=xs',
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          (frame == null && !wasSynchronouslyLoaded)
          ? const SizedBox.shrink()
          : child,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        fallback,
        // Nacht: Foto abdunkeln und bläulich einfärben
        dark
            ? ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Color(0xFF3B4A8F),
                  BlendMode.multiply,
                ),
                child: photo,
              )
            : photo,
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: dark ? 0.25 : 0.05),
                Colors.black.withValues(alpha: dark ? 0.6 : 0.35),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
