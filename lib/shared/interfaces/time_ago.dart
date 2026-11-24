import '../../l10n/generated/app_localizations.dart';

/// Relative time as the mockups write it: "hace 2 min", "hace 3 h".
String timeAgo(AppLocalizations l10n, DateTime from, DateTime now) {
  final elapsed = now.difference(from);
  if (elapsed.inMinutes < 1) return l10n.timeAgoNow;
  if (elapsed.inHours < 1) return l10n.timeAgoMinutes(elapsed.inMinutes);
  if (elapsed.inDays < 1) return l10n.timeAgoHours(elapsed.inHours);
  return l10n.timeAgoDays(elapsed.inDays);
}
