import 'package:auxia_mobile/core/database/app_database.dart';
import 'package:auxia_mobile/core/localization/locale_cubit.dart';
import 'package:auxia_mobile/core/localization/locale_store.dart';
import 'package:auxia_mobile/core/maps/map_region.dart';
import 'package:auxia_mobile/core/sync/outbox_repository.dart';
import 'package:auxia_mobile/core/sync/sync_cubit.dart';
import 'package:auxia_mobile/emergencymanagement/application/sos_service.dart';
import 'package:auxia_mobile/emergencymanagement/domain/model/citizen_report.dart';
import 'package:auxia_mobile/emergencymanagement/infrastructure/persistence/sqlite_citizen_report_repository.dart';
import 'package:auxia_mobile/identityaccess/application/auth_service.dart';
import 'package:auxia_mobile/identityaccess/application/profile_service.dart';
import 'package:auxia_mobile/identityaccess/domain/model/local_profile.dart';
import 'package:auxia_mobile/identityaccess/domain/model/user_role.dart';
import 'package:auxia_mobile/identityaccess/domain/model/valueobjects.dart';
import 'package:auxia_mobile/identityaccess/interfaces/profile_cubit.dart';
import 'package:auxia_mobile/networkstorage/infrastructure/sqlite_storage_stats.dart';
import 'package:auxia_mobile/networkstorage/interfaces/pages/network_storage/network_storage_cubit.dart';
import 'package:auxia_mobile/networkstorage/interfaces/pages/network_storage/network_storage_screen.dart';
import 'package:auxia_mobile/resourcemanagement/infrastructure/persistence/sqlite_mission_cache.dart';
import 'package:auxia_mobile/shared/domain/geo_point.dart';
import 'package:auxia_mobile/shared/interfaces/format_bytes.dart';
import 'package:auxia_mobile/traceability/domain/model/delivery.dart';
import 'package:auxia_mobile/traceability/infrastructure/persistence/sqlite_delivery_record_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../helpers/test_app.dart';

void main() {
  late Database db;

  setUp(() async => db = await openTestDatabase());
  tearDown(() => db.close());

  test('sizes are written as the storage screens show them', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(120 * 1024), '120 KB');
    expect(formatBytes((3.8 * 1024 * 1024).round()), '3.8 MB');
    expect(formatBytes(200 * 1024 * 1024), '200 MB');
  });

  test('counts the figures of the local database', () async {
    final outbox = OutboxRepository(db);
    final reports = SqliteCitizenReportRepository(db);
    await SosService(reports, outbox).sendSos(category: HelpCategory.medical);
    await SqliteMissionCache(db).saveMission(sampleMission());
    final records = SqliteDeliveryRecordRepository(db);
    await records.save(
      DeliveryRecord(
        order: sampleOrder,
        deliveredAt: DateTime(2026, 11, 6),
        signaturePath: '/s.png',
        photoPath: '/p.jpg',
        status: DeliveryRecordStatus.queued,
      ),
    );

    final stats = await SqliteStorageStats(AppDatabase(db)).read();

    expect(stats.citizenReports, 1);
    expect(stats.pendingSync, 1);
    expect(stats.missions, 1);
    expect(stats.evidenceToUpload, 2);
    expect(stats.blockchainQueue, 1);
    expect(stats.databaseBytes, greaterThan(0));
    expect(stats.intact, isTrue);
  });

  test('the chosen language is kept for the next launch', () async {
    final store = LocaleStore(db);
    final cubit = LocaleCubit(LocaleCubit.defaultLocale, store.save);

    cubit.change(const Locale('en'));
    await Future<void>.delayed(Duration.zero);

    expect(await store.load(), const Locale('en'));
  });

  group('NetworkStorageScreen (A_06 / A_09)', () {
    late LocaleCubit localeCubit;

    Future<void> pump(WidgetTester tester, UserRole role) async {
      tester.view.physicalSize = const Size(1170, 6000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final profiles = InMemoryProfileRepository(
        LocalProfile.register(
          fullName: FullName('María Quispe'),
          phone: PhoneNumber('987654321'),
          role: role,
          now: DateTime(2026, 11, 6),
        ),
      );
      final profileCubit = ProfileCubit(
        ProfileService(profiles),
        AuthService(
          FakeAuthenticationGateway(),
          InMemorySessionRepository(),
          profiles,
        ),
      );
      await profileCubit.load();
      localeCubit = LocaleCubit();
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: profileCubit),
            BlocProvider.value(value: localeCubit),
            BlocProvider(create: (_) => SyncCubit(FakeSyncController())),
            BlocProvider(
              create: (_) => NetworkStorageCubit(
                SqliteStorageStats(AppDatabase(db)),
                dataChanges: const Stream.empty(),
                loadRegions: () async => [
                  MapRegion(
                    id: 'zone-1',
                    name: 'Sector Norte',
                    center: const GeoPoint(-12.0, -77.0),
                    assigned: role == UserRole.brigadist,
                  ),
                ],
              )..start(),
            ),
          ],
          child: BlocBuilder<LocaleCubit, Locale>(
            builder: (context, locale) =>
                localizedApp(const NetworkStorageScreen(), locale: locale),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a citizen sees maps by region and the local reports', (
      tester,
    ) async {
      await pump(tester, UserRole.citizen);

      expect(find.text('Red y almacenamiento'), findsOneWidget);
      expect(find.text('MAPAS OFFLINE POR REGIÓN'), findsOneWidget);
      expect(find.text('Sector Norte'), findsOneWidget);
      expect(
        find.text('Disponible offline · mapa dibujado en el teléfono'),
        findsOneWidget,
      );
      expect(find.text('Descargar'), findsNothing);
      expect(find.text('BASE DE DATOS LOCAL · SQLITE'), findsOneWidget);
      expect(find.text('Reportes locales'), findsOneWidget);
      expect(find.text('Cifrada · OK'), findsOneWidget);
      expect(find.text('Sincronizar ahora'), findsOneWidget);
    });

    testWidgets('a brigadist sees the assigned zone and the queues', (
      tester,
    ) async {
      await pump(tester, UserRole.brigadist);

      expect(find.text('MAPAS DE TU ZONA ASIGNADA'), findsOneWidget);
      expect(find.text('Sector Norte · Asignada'), findsOneWidget);
      expect(find.text('Evidencias por subir'), findsOneWidget);
      expect(find.text('Tx Blockchain en cola'), findsOneWidget);
    });

    testWidgets('the language can be switched to english', (tester) async {
      await pump(tester, UserRole.citizen);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(localeCubit.state, const Locale('en'));
      expect(find.text('Network and storage'), findsOneWidget);
    });
  });
}
