import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:auxia_mobile/core/config/app_config.dart';
import 'package:auxia_mobile/core/connectivity/connectivity_monitor.dart';
import 'package:auxia_mobile/core/database/app_database.dart';
import 'package:auxia_mobile/core/failure.dart';
import 'package:auxia_mobile/core/location/location_service.dart';
import 'package:auxia_mobile/core/network/api_client.dart';
import 'package:auxia_mobile/core/sync/sync_engine.dart';
import 'package:auxia_mobile/core/theme/app_theme.dart';
import 'package:auxia_mobile/emergencymanagement/application/quick_evidence.dart';
import 'package:auxia_mobile/emergencymanagement/domain/model/citizen_report.dart';
import 'package:auxia_mobile/emergencymanagement/domain/repositories/citizen_report_gateway.dart';
import 'package:auxia_mobile/identityaccess/domain/model/local_profile.dart';
import 'package:auxia_mobile/identityaccess/domain/model/session.dart';
import 'package:auxia_mobile/identityaccess/domain/repositories/profile_repository.dart';
import 'package:auxia_mobile/identityaccess/domain/repositories/session_repository.dart';
import 'package:auxia_mobile/l10n/generated/app_localizations.dart';
import 'package:auxia_mobile/shared/domain/geo_point.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Wraps a screen with the AuxIA theme and the Spanish localizations.
Widget localizedApp(Widget home, {Locale locale = const Locale('es')}) =>
    MaterialApp(
      theme: AppTheme.dark(),
      locale: locale,
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

/// Profile repository kept in memory.
class InMemoryProfileRepository implements ProfileRepository {
  InMemoryProfileRepository([this.profile]);

  LocalProfile? profile;

  @override
  Future<LocalProfile?> load() async => profile;

  @override
  Future<void> save(LocalProfile profile) async => this.profile = profile;

  @override
  Future<void> clear() async => profile = null;
}

/// Session repository kept in memory.
class InMemorySessionRepository implements SessionRepository {
  Session? session;

  @override
  Future<Session?> load() async => session;

  @override
  Future<void> save(Session session) async => this.session = session;

  @override
  Future<void> clear() async => session = null;
}

/// Sign-in gateway that answers with a fixed result.
class FakeAuthenticationGateway implements AuthenticationGateway {
  FakeAuthenticationGateway([Either<Failure, Session>? result])
    : result = result ?? Right(brigadeSession());

  Either<Failure, Session> result;
  String? lastEmail;

  @override
  Future<Either<Failure, Session>> signIn({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    return result;
  }
}

Session brigadeSession({
  AccountRole role = AccountRole.fieldBrigade,
  DateTime? expiresAt,
}) => Session(
  token: 'token-123',
  expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 8)),
  userId: 'user-1',
  organizationId: 'org-1',
  role: role,
  fullName: 'Cap. M. Quispe',
);

/// Network that the test turns on and off.
class FakeConnectivityMonitor implements ConnectivityMonitor {
  FakeConnectivityMonitor({bool online = true})
    : status = online
          ? const NetworkStatus({NetworkChannel.cellular})
          : const NetworkStatus.offline();

  NetworkStatus status;
  final StreamController<NetworkStatus> _changes = StreamController.broadcast();

  void set({required bool online}) {
    status = online
        ? const NetworkStatus({NetworkChannel.cellular})
        : const NetworkStatus.offline();
    _changes.add(status);
  }

  @override
  Future<NetworkStatus> current() async => status;

  @override
  Stream<NetworkStatus> get changes => _changes.stream;
}

/// Sync controller with a fixed state, for widget tests.
class FakeSyncController implements SyncController {
  FakeSyncController([this.state = const SyncState()]);

  @override
  SyncState state;
  final StreamController<SyncState> _states = StreamController.broadcast();
  int syncCalls = 0;
  int retryCalls = 0;

  void emit(SyncState next) {
    state = next;
    _states.add(next);
  }

  @override
  Stream<SyncState> get states => _states.stream;

  @override
  Future<void> syncNow() async => syncCalls++;

  @override
  Future<void> retryAll() async => retryCalls++;

  @override
  void sessionRestored() {}
}

/// Fresh in-memory copy of the app database (sqflite over FFI, in the same
/// isolate so it also works inside widget tests).
Future<Database> openTestDatabase() async {
  sqfliteFfiInit();
  final options = AppDatabase.options();
  return databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: options.version,
      onConfigure: options.onConfigure,
      onCreate: options.onCreate,
      onUpgrade: options.onUpgrade,
      singleInstance: false,
    ),
  );
}

/// GPS that answers with a fixed result.
class FakeLocationService implements LocationService {
  FakeLocationService([
    this.result = const LocationFix(GeoPoint(-12.0464, -77.0428)),
  ]);

  LocationResult result;

  @override
  Future<LocationResult> locate({Duration timeout = Duration.zero}) async =>
      result;
}

/// Camera and microphone that return fixed files.
class FakeQuickEvidence implements QuickEvidence {
  bool microphoneAllowed = true;
  bool recording = false;
  String? photo = '/evidence/photo.jpg';

  @override
  Future<String?> takePhoto() async => photo;

  @override
  Future<bool> startAudio() async => recording = microphoneAllowed;

  @override
  Future<String?> stopAudio() async {
    recording = false;
    return '/evidence/audio.m4a';
  }
}

/// HTTP adapter that answers by "METHOD path" and records the requests.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.routes);

  /// "POST /api/v1/x" → (status, json body).
  final Map<String, (int, Object?)> routes;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final key = '${options.method} ${options.uri.path}';
    final (status, body) = routes[key] ?? (404, {'detail': 'Not Found'});
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// API client over a [FakeHttpAdapter].
ApiClient fakeApiClient(FakeHttpAdapter adapter, {String? token}) => ApiClient(
  config: const AppConfig(apiBaseUrl: 'https://api.test'),
  accessToken: () async => token,
  language: () => 'es',
  dio: Dio()..httpClientAdapter = adapter,
);

/// Citizen report gateway with scripted answers.
class FakeCitizenReportGateway implements CitizenReportGateway {
  Either<Failure, Unit> submitResult = const Right(unit);
  final Map<String, Either<Failure, RemoteReportStatus>> statuses = {};
  final List<(String, String)> submitted = [];

  @override
  Future<Either<Failure, Unit>> submit(
    CitizenReport report, {
    String? clientReportId,
    String? text,
    CitizenReport? relatedReport,
  }) async {
    submitted.add((clientReportId ?? report.id, text ?? report.toReportText()));
    return submitResult;
  }

  @override
  Future<Either<Failure, RemoteReportStatus>> status(String id) async =>
      statuses[id] ?? const Left(NetworkFailure());
}
