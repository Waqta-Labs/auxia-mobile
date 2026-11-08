import 'package:auxia_mobile/core/sync/outbox_repository.dart';
import 'package:auxia_mobile/emergencymanagement/application/mesh_relay_service.dart';
import 'package:auxia_mobile/emergencymanagement/application/mesh_service.dart';
import 'package:auxia_mobile/emergencymanagement/application/sos_service.dart';
import 'package:auxia_mobile/emergencymanagement/domain/model/citizen_report.dart';
import 'package:auxia_mobile/emergencymanagement/infrastructure/api/http_citizen_report_gateway.dart';
import 'package:auxia_mobile/emergencymanagement/infrastructure/persistence/sqlite_citizen_report_repository.dart';
import 'package:auxia_mobile/emergencymanagement/infrastructure/persistence/sqlite_mesh_relay_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

/// The air between the fake phones: what one sends, the other receives.
class _Air {
  final Map<String, _Radio> radios = {};

  void meet(_Radio a, _Radio b) {
    a._onConnected(b.name);
    b._onConnected(a.name);
  }

  void part(_Radio a, _Radio b) {
    a._onDisconnected(b.name);
    b._onDisconnected(a.name);
  }
}

class _Radio implements MeshNetwork {
  _Radio(this.name, this.air) {
    air.radios[name] = this;
  }

  final String name;
  final _Air air;
  bool running = false;
  late void Function(String) _onConnected;
  late void Function(String) _onDisconnected;
  late void Function(String, List<int>) _onBytes;

  @override
  bool get supported => true;

  @override
  Future<void> start({
    required void Function(String peer) onConnected,
    required void Function(String peer) onDisconnected,
    required void Function(String peer, List<int> bytes) onBytes,
  }) async {
    running = true;
    _onConnected = onConnected;
    _onDisconnected = onDisconnected;
    _onBytes = onBytes;
  }

  @override
  Future<void> send(String peer, List<int> bytes) async =>
      air.radios[peer]!._onBytes(name, bytes);

  @override
  Future<void> stop() async => running = false;
}

class _Permissions implements MeshPermissions {
  bool granted = true;

  @override
  Future<bool> request() async => granted;
}

class _Settings implements MeshSettings {
  bool on = false;

  @override
  Future<bool> enabled() async => on;

  @override
  Future<void> setEnabled(bool enabled) async => on = enabled;
}

/// A phone with its own database, Mesh and outbox.
class _Phone {
  _Phone._(this.reports, this.outbox, this.mesh, this.radio, this.settings);

  static Future<_Phone> open(String name, _Air air) async {
    final db = await openTestDatabase();
    final reports = SqliteCitizenReportRepository(db);
    final outbox = OutboxRepository(db);
    final radio = _Radio(name, air);
    final settings = _Settings();
    final relay = MeshRelayService(
      reports,
      SqliteMeshRelayRepository(db),
      outbox,
      bodyOf: citizenReportBody,
    );
    return _Phone._(
      reports,
      outbox,
      MeshService(radio, _Permissions(), settings, relay),
      radio,
      settings,
    );
  }

  final SqliteCitizenReportRepository reports;
  final OutboxRepository outbox;
  final MeshService mesh;
  final _Radio radio;
  final _Settings settings;
}

void main() {
  late _Air air;
  late _Phone maria;
  late _Phone vecino;

  setUp(() async {
    air = _Air();
    maria = await _Phone.open('maria', air);
    vecino = await _Phone.open('vecino', air);
  });

  tearDown(() async {
    await maria.mesh.dispose();
    await vecino.mesh.dispose();
  });

  test(
    'an SOS without signal reaches a nearby phone, which queues it',
    () async {
      final sos = (await SosService(
        maria.reports,
        maria.outbox,
      ).sendSos(category: HelpCategory.rescue)).getRight().toNullable()!;
      await maria.mesh.setEnabled(true);
      await vecino.mesh.setEnabled(true);

      air.meet(maria.radio, vecino.radio);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(maria.mesh.state.peers, 1);
      expect(maria.mesh.state.available, isTrue);
      final queued = await vecino.outbox.find('relay-${sos.id}');
      expect(queued!.type, CitizenOutboxTypes.relay);
      expect(queued.payload, {'clientReportId': sos.id});
    },
  );

  test('Mesh stays off until the user turns it on', () async {
    expect(maria.mesh.state.enabled, isFalse);
    await maria.mesh.start();
    expect(maria.radio.running, isFalse);

    maria.settings.on = true;
    await maria.mesh.start();
    expect(maria.radio.running, isTrue);
    expect(maria.mesh.state.enabled, isTrue);

    await maria.mesh.setEnabled(false);
    expect(maria.radio.running, isFalse);
    expect(maria.settings.on, isFalse);
  });

  test('without the permissions it stays off and says so', () async {
    final denied = MeshService(
      _Radio('solo', air),
      _Permissions()..granted = false,
      _Settings(),
      MeshRelayService(
        maria.reports,
        SqliteMeshRelayRepository(await openTestDatabase()),
        maria.outbox,
        bodyOf: citizenReportBody,
      ),
    );
    addTearDown(denied.dispose);

    await denied.setEnabled(true);

    expect(denied.state.enabled, isFalse);
    expect(denied.state.permissionDenied, isTrue);
  });

  test('a phone that moves away is no longer counted', () async {
    await maria.mesh.setEnabled(true);
    await vecino.mesh.setEnabled(true);
    air.meet(maria.radio, vecino.radio);
    await Future<void>.delayed(Duration.zero);

    air.part(maria.radio, vecino.radio);

    expect(maria.mesh.state.peers, 0);
    expect(maria.mesh.state.available, isFalse);
  });
}
