import 'package:go_router/go_router.dart';

import '../../shared/interfaces/pages/startup/startup_screen.dart';

/// Paths of the app. Each screen of the report gets its own constant.
abstract final class AppRoutes {
  static const String startup = '/';
}

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.startup,
    routes: [
      GoRoute(
        path: AppRoutes.startup,
        builder: (context, state) => const StartupScreen(),
      ),
    ],
  );
}
