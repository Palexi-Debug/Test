import 'package:liblanis/liblanis.dart';

/// Verständliche deutsche Meldung für bestimmte Anmelde-Fehler des Portals,
/// sonst null (dann gilt die normale Fehlermeldung).
String? friendlyLoginError(Object e) {
  if (e is PasswordChangeRequiredException) {
    return 'Du musst dein Passwort im Schulportal Hessen ändern, bevor du dich anmelden kannst. Öffne dazu das Portal im Browser.';
  }
  if (e is AccountDisabledException) {
    return 'Dieses Konto wurde von deiner Schule gesperrt.';
  }
  if (e is ParentAccountWithoutLearnersException) {
    return 'Zu diesem Eltern-Konto sind keine Lernenden hinterlegt.';
  }
  return null;
}

/// Fehler, bei denen kein Offline-Betrieb mit gespeicherten Daten sinnvoll ist.
bool isAccountProblem(Object e) =>
    e is PasswordChangeRequiredException ||
    e is AccountDisabledException ||
    e is ParentAccountWithoutLearnersException;
