import 'package:auxia_mobile/core/connectivity/connectivity_monitor.dart';
import 'package:auxia_mobile/core/sync/sync_cubit.dart';
import 'package:auxia_mobile/core/sync/sync_engine.dart';
import 'package:auxia_mobile/shared/interfaces/widgets/connectivity_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

Widget _badge(SyncState state, ConnectivityBadgeStyle style) => BlocProvider(
  create: (_) => SyncCubit(FakeSyncController(state)),
  child: localizedApp(
    Scaffold(
      body: Column(
        children: [
          ConnectivityBadge(style: style),
          const SyncProgressBar(),
        ],
      ),
    ),
  ),
);

void main() {
  const online = SyncState(network: NetworkStatus({NetworkChannel.wifi}));
  const offline = SyncState();

  testWidgets('offline, the app says it keeps working', (tester) async {
    await tester.pumpWidget(_badge(offline, ConnectivityBadgeStyle.mode));
    await tester.pumpAndSettle();

    expect(find.text('Modo Offline Activo'), findsOneWidget);
  });

  testWidgets('offline, the signal badge says there is no signal', (
    tester,
  ) async {
    await tester.pumpWidget(_badge(offline, ConnectivityBadgeStyle.signal));
    await tester.pumpAndSettle();

    expect(find.text('Sin señal'), findsOneWidget);
  });

  testWidgets('online, the badge says so', (tester) async {
    await tester.pumpWidget(_badge(online, ConnectivityBadgeStyle.mode));
    await tester.pumpAndSettle();

    expect(find.text('En línea'), findsOneWidget);
  });

  testWidgets('the progress bar appears only while syncing', (tester) async {
    final controller = FakeSyncController(online);
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => SyncCubit(controller),
        child: localizedApp(const Scaffold(body: SyncProgressBar())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);

    controller.emit(online.copyWith(running: true, total: 4, done: 1));
    await tester.pump();
    await tester.pump();

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.25);
  });
}
