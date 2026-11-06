import 'dart:async';

import 'package:auxia_mobile/core/connectivity/connectivity_monitor.dart';
import 'package:auxia_mobile/core/database/app_database.dart';
import 'package:auxia_mobile/core/failure.dart';
import 'package:auxia_mobile/core/sync/sync_engine.dart';
import 'package:auxia_mobile/core/theme/app_theme.dart';
import 'package:auxia_mobile/identityaccess/domain/model/local_profile.dart';
import 'package:auxia_mobile/identityaccess/domain/model/session.dart';
import 'package:auxia_mobile/identityaccess/domain/repositories/profile_repository.dart';
import 'package:auxia_mobile/identityaccess/domain/repositories/session_repository.dart';
import 'package:auxia_mobile/l10n/generated/app_localizations.dart';
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

/// Fresh in-memory copy of the app database (sqflite over FFI).
Future<Database> openTestDatabase() async {
  sqfliteFfiInit();
  final options = AppDatabase.options();
  return databaseFactoryFfi.openDatabase(
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
