import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Opens a bottom sheet where the beneficiary signs with the finger and
/// returns the signature as PNG, or null if it was closed.
Future<Uint8List?> showSignatureSheet(BuildContext context) =>
    showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      builder: (_) => const _SignatureSheet(),
    );

class _SignatureSheet extends StatefulWidget {
  const _SignatureSheet();

  @override
  State<_SignatureSheet> createState() => _SignatureSheetState();
}

class _SignatureSheetState extends State<_SignatureSheet> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: AppColors.surfaceDeep,
    exportBackgroundColor: AppColors.white,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.isEmpty) return;
    final png = await _controller.toPngBytes();
    if (mounted) Navigator.of(context).pop(png);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.deliverySignature,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Signature(
                controller: _controller,
                height: 220,
                backgroundColor: AppColors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _controller.clear,
                    child: Text(l10n.actionClear),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(l10n.actionSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
