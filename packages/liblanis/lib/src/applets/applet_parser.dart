import 'dart:async';
import 'dart:convert';

import '../exceptions.dart';
import '../lanis_client.dart';
import 'applet_context.dart';
import 'definition.dart';

enum FetcherStatus { fetching, done, error }

enum ContentStatus { online, offline }

class ExceptionWithStackTrace {
  final Object exception;
  final StackTrace stackTrace;

  ExceptionWithStackTrace({required this.exception, required this.stackTrace});
}

class FetcherResponse<T> {
  final FetcherStatus status;
  final T? content;
  final ContentStatus contentStatus;
  final DateTime fetchedAt;
  final ExceptionWithStackTrace? error;

  FetcherResponse({
    required this.status,
    this.contentStatus = ContentStatus.online,
    required this.error,
    this.content,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();
}

class AppletResponseStream<T> extends StreamView<FetcherResponse<T>> {
  final FetcherResponse<T>? Function() _valueGetter;

  AppletResponseStream(super.stream, this._valueGetter);

  FetcherResponse<T> get value => _valueGetter()!;
}

/// Base class for SPH applet parsers (Dart-only, no Flutter).
class AppletParser<T> {
  final AppletContext ctx;
  final AppletMeta appletMeta;
  final Future<bool> Function() isConnected;

  final StreamController<FetcherResponse<T>> _controller =
      StreamController<FetcherResponse<T>>.broadcast();
  FetcherResponse<T> _latestResponse = FetcherResponse(
    status: FetcherStatus.fetching,
    error: null,
  );
  late final AppletResponseStream<T> _stream = AppletResponseStream<T>(
    _controller.stream,
    () => _latestResponse,
  );
  bool isEmpty = true;
  Timer? _refreshTimer;

  AppletResponseStream<T> get stream => _stream;

  FetcherResponse<T>? get latestResponse => _latestResponse;

  AppletParser(
    this.ctx,
    this.appletMeta, {
    required this.isConnected,
  });

  /// Starts periodic refresh. Safe to call repeatedly.
  void startAutoRefresh() {
    if (_refreshTimer != null || _controller.isClosed) return;
    _refreshTimer = Timer.periodic(appletMeta.refreshInterval, timerCallback);
  }

  /// Stops periodic refresh while the applet is off-screen.
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void timerCallback(Timer timer) async {
    if (await isConnected()) {
      await fetchData(forceRefresh: true);
    }
  }

  void addResponse(final FetcherResponse<T> data) {
    _latestResponse = data;
    if (!_controller.isClosed) {
      _controller.add(data);
    }
  }

  void dispose() {
    stopAutoRefresh();
    _controller.close();
  }

  /// Zeigt gespeicherte Daten (offline): zuerst die zuletzt geladenen Daten im
  /// Speicher, sonst den Cache aus der Datenbank. Gibt `false` zurück, wenn es
  /// nichts zu zeigen gibt.
  bool _emitOfflineFallback(FetcherResponse<T> previous) {
    if (previous.content != null) {
      addResponse(
        FetcherResponse<T>(
          status: FetcherStatus.done,
          contentStatus: ContentStatus.offline,
          content: previous.content,
          fetchedAt: previous.fetchedAt,
          error: null,
        ),
      );
      return true;
    }
    if (!appletMeta.allowOffline) return false;
    try {
      final offlineData = ctx.database.getAppletOfflineData(
        accountId: ctx.accountId,
        appletId: appletMeta.appletPhpUrl,
      );
      if (offlineData == null) return false;
      final content = typeFromJson(offlineData.json);
      addResponse(
        FetcherResponse<T>(
          status: FetcherStatus.done,
          contentStatus: ContentStatus.offline,
          content: content,
          fetchedAt: offlineData.timestamp,
          error: null,
        ),
      );
      return true;
    } catch (_) {
      // Kaputter Cache: verwerfen, damit er nicht dauerhaft stört.
      try {
        ctx.database.deleteAppletOfflineData(
          accountId: ctx.accountId,
          appletId: appletMeta.appletPhpUrl,
        );
      } catch (_) {}
      return false;
    }
  }

  Future<void> fetchData({
    bool forceRefresh = false,
    bool secondTry = false,
  }) async {
    // Gespeicherte Daten sofort zeigen (veraltet), während geprüft/geladen wird.
    if (_latestResponse.content == null && appletMeta.allowOffline) {
      _emitOfflineFallback(_latestResponse);
    }
    var connected = await isConnected();
    if (!connected && !secondTry) {
      // Schlechtes Netz: kurz warten und einmal erneut prüfen, bevor "offline".
      await Future<void>.delayed(const Duration(seconds: 2));
      connected = await isConnected();
    }
    if (!connected) {
      if (isEmpty || _latestResponse.content == null) {
        if (!_emitOfflineFallback(_latestResponse)) {
          addResponse(
            FetcherResponse(
              status: FetcherStatus.error,
              contentStatus: ContentStatus.offline,
              error: null,
            ),
          );
        }
      } else if (_latestResponse.contentStatus != ContentStatus.offline) {
        // Verbindung verloren: vorhandene Daten bleiben, mit Offline-Hinweis.
        _emitOfflineFallback(_latestResponse);
      }
      return;
    }

    if (isEmpty || forceRefresh) {
      final previous = _latestResponse;
      // Vorhandene Daten bleiben beim Aktualisieren sichtbar.
      if (previous.content == null) {
        addResponse(
          FetcherResponse(status: FetcherStatus.fetching, error: null),
        );
      }

      try {
        final data = await _getHome();
        addResponse(
          FetcherResponse<T>(
            status: FetcherStatus.done,
            content: data,
            error: null,
          ),
        );
        isEmpty = false;
      } catch (ex, stack) {
        if (!secondTry) {
          try {
            await ctx.session.authenticate();
          } catch (authError, authStack) {
            _reportUnexpectedError(authError, authStack);
            // Portal nicht erreichbar/Login fehlgeschlagen: gespeicherte
            // Daten zeigen, falls vorhanden.
            if (_emitOfflineFallback(previous)) return;
            addResponse(
              FetcherResponse<T>(
                status: FetcherStatus.error,
                error: ExceptionWithStackTrace(
                  exception: authError,
                  stackTrace: authStack,
                ),
              ),
            );
            return;
          }
          await fetchData(forceRefresh: true, secondTry: true);
          return;
        }
        _reportUnexpectedError(ex, stack);
        if (_emitOfflineFallback(previous)) return;
        addResponse(
          FetcherResponse<T>(
            status: FetcherStatus.error,
            error: ExceptionWithStackTrace(
              exception: ex,
              stackTrace: stack,
            ),
          ),
        );
      }
    }
  }

  void _reportUnexpectedError(Object error, StackTrace stackTrace) {
    if (!isUnexpectedParserError(error)) return;
    final handler = LanisClient.config?.onUnexpectedError;
    if (handler == null) return;
    try {
      handler(
        error,
        stackTrace,
        appletPhpUrl: appletMeta.appletPhpUrl,
      );
    } catch (_) {
      // Host reporter must never break the fetch stream.
    }
  }

  Future<T> _getHome() async {
    final T value = await getHome();
    if (appletMeta.allowOffline) {
      final newJson = jsonEncode(value);
      // Ein plötzlich fast leerer Plan (schlechtes Netz) überschreibt keinen
      // guten Cache.
      var keepOld = false;
      try {
        final old = ctx.database.getAppletOfflineData(
          accountId: ctx.accountId,
          appletId: appletMeta.appletPhpUrl,
        );
        if (old != null &&
            old.json.length > 800 &&
            newJson.length < old.json.length * 0.25) {
          keepOld = true;
        }
      } catch (_) {}
      if (!keepOld) {
        ctx.database.setAppletOfflineData(
          accountId: ctx.accountId,
          appletId: appletMeta.appletPhpUrl,
          json: newJson,
        );
      }
    }
    return value;
  }

  T typeFromJson(String json) {
    throw UnimplementedError('Please add the required overrides in the parser');
  }

  Future<T> getHome() {
    throw UnimplementedError();
  }
}
