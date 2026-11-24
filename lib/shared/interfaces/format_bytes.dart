/// "3.8 MB", "120 KB", as the storage screens show sizes.
String formatBytes(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  String amount(double value) =>
      value < 10 ? value.toStringAsFixed(1) : value.round().toString();
  if (bytes >= gb) return '${amount(bytes / gb)} GB';
  if (bytes >= mb) return '${amount(bytes / mb)} MB';
  if (bytes >= kb) return '${(bytes / kb).round()} KB';
  return '$bytes B';
}
