import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'connectivity_badge.dart';

/// One entry of the bottom navigation.
class RoleDestination {
  const RoleDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Fixed bottom navigation with the three sections of each role (report
/// 6.1.2 A and 6.2.5): SOS, Mis reportes, Ajustes for citizens; Misiones,
/// Entrega, Ajustes for brigadists.
class RoleNavigationShell extends StatelessWidget {
  const RoleNavigationShell({
    super.key,
    required this.shell,
    required this.destinations,
  });

  final StatefulNavigationShell shell;
  final List<RoleDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          shell,
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(bottom: false, child: SyncProgressBar()),
          ),
        ],
      ),
      // The labels of the bar cannot wrap; they grow with the system text
      // size up to a limit so they fit on small phones.
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (index) => shell.goBranch(
            index,
            initialLocation: index == shell.currentIndex,
          ),
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      ),
    );
  }
}
