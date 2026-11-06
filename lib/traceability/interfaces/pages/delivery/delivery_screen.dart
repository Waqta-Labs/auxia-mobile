import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/interfaces/time_ago.dart';
import '../../../../shared/interfaces/widgets/app_card.dart';
import '../../../../shared/interfaces/widgets/bottom_action_area.dart';
import '../../../../shared/interfaces/widgets/empty_state.dart';
import '../../../../shared/interfaces/widgets/screen_header.dart';
import '../../../../shared/interfaces/widgets/status_chip.dart';
import '../../../domain/model/delivery.dart';
import '../../widgets/qr_scanner_view.dart';
import '../../widgets/signature_sheet.dart';
import 'delivery_cubit.dart';

/// Builds the QR reader; tests replace the camera.
typedef ScannerBuilder = Widget Function(ValueChanged<String> onDetect);

/// A_08 · Verificar entrega, or its empty state without an open mission.
class DeliveryScreen extends StatelessWidget {
  const DeliveryScreen({
    super.key,
    required this.order,
    required this.createCubit,
    required this.onNextMission,
    required this.onOpenTransaction,
    this.scannerBuilder,
  });

  /// Delivery of the active mission, or null.
  final DeliveryOrder? order;
  final DeliveryCubit Function(DeliveryOrder order) createCubit;
  final VoidCallback onNextMission;
  final ValueChanged<String> onOpenTransaction;
  final ScannerBuilder? scannerBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final order = this.order;
    if (order == null) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screen,
              vertical: AppSpacing.md,
            ),
            children: [
              ScreenHeader(title: l10n.deliveryTitle),
              const SizedBox(height: AppSpacing.lg),
              EmptyState(
                icon: Icons.qr_code_scanner,
                message: l10n.deliveryEmpty,
              ),
            ],
          ),
        ),
      );
    }
    return BlocProvider(
      key: ValueKey(order.deliveryId),
      create: (_) => createCubit(order)..start(),
      child: _DeliveryView(
        onNextMission: onNextMission,
        onOpenTransaction: onOpenTransaction,
        scannerBuilder:
            scannerBuilder ?? (onDetect) => QrScannerView(onDetect: onDetect),
      ),
    );
  }
}

class _DeliveryView extends StatelessWidget {
  const _DeliveryView({
    required this.onNextMission,
    required this.onOpenTransaction,
    required this.scannerBuilder,
  });

  final VoidCallback onNextMission;
  final ValueChanged<String> onOpenTransaction;
  final ScannerBuilder scannerBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocListener<DeliveryCubit, DeliveryState>(
      listenWhen: (previous, current) =>
          (previous.step == DeliveryStep.scan &&
              current.step == DeliveryStep.evidence) ||
          (previous.record?.status != DeliveryRecordStatus.anchored &&
              current.record?.status == DeliveryRecordStatus.anchored) ||
          (!previous.cameraFailed && current.cameraFailed),
      listener: (context, state) {
        if (state.cameraFailed && state.step == DeliveryStep.evidence) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.cameraError)));
          return;
        }
        // 6.1.2 C: haptic confirmation of the QR scan and of the seal.
        HapticFeedback.mediumImpact();
      },
      child: Scaffold(
        body: BlocBuilder<DeliveryCubit, DeliveryState>(
          builder: (context, state) {
            final cubit = context.read<DeliveryCubit>();
            return BottomActionLayout(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScreenHeader(
                    title: l10n.deliveryTitle,
                    trailing: StatusChip(
                      label: state.order.shortCode,
                      tone: StatusTone.info,
                      showDot: false,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Steps(completed: state.completedSteps),
                  const SizedBox(height: AppSpacing.md),
                  if (state.step == DeliveryStep.scan)
                    _ScanStep(state: state, scannerBuilder: scannerBuilder)
                  else ...[
                    _PackageCard(
                      state: state,
                      editable: state.step == DeliveryStep.evidence,
                      onChange: cubit.changeQuantity,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _EvidenceRow(
                      state: state,
                      editable: state.step == DeliveryStep.evidence,
                    ),
                    if (state.record != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _BlockchainCard(
                        record: state.record!,
                        onOpenTransaction: onOpenTransaction,
                      ),
                    ],
                  ],
                ],
              ),
              actions: [
                if (state.step == DeliveryStep.scan)
                  OutlinedButton(
                    onPressed: () => _typeCode(context),
                    child: Text(l10n.deliveryManualCode),
                  ),
                if (state.step == DeliveryStep.evidence) ...[
                  if (!state.evidenceComplete)
                    Text(
                      l10n.deliveryEvidenceMissing,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  FilledButton(
                    onPressed: state.evidenceComplete && !state.submitting
                        ? cubit.submit
                        : null,
                    child: Text(l10n.actionRegisterDelivery),
                  ),
                  TextButton(
                    onPressed: cubit.rescan,
                    child: Text(l10n.actionScanAgain),
                  ),
                ],
                if (state.step == DeliveryStep.blockchain) ...[
                  if (state.record?.status == DeliveryRecordStatus.registered)
                    OutlinedButton(
                      onPressed: cubit.refresh,
                      child: Text(l10n.actionRefreshStatus),
                    ),
                  FilledButton(
                    onPressed: onNextMission,
                    child: Text(l10n.actionNextMission),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _typeCode(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DeliveryCubit>();
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deliveryManualCode),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.deliveryCodeLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.actionConfirm),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code != null && code.trim().isNotEmpty) cubit.scanned(code);
  }
}

/// "1 · Escaneo ✓  2 · Evidencia ✓  3 · Blockchain ✓".
class _Steps extends StatelessWidget {
  const _Steps({required this.completed});

  final int completed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.deliveryStepScan,
      l10n.deliveryStepEvidence,
      l10n.deliveryStepBlockchain,
    ];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i < completed ? AppColors.lime : AppColors.track,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${labels[i]}${i < completed ? ' ✓' : ''}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: i < completed
                        ? AppColors.lime
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ScanStep extends StatelessWidget {
  const _ScanStep({required this.state, required this.scannerBuilder});

  final DeliveryState state;
  final ScannerBuilder scannerBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        scannerBuilder(context.read<DeliveryCubit>().scanned),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.deliveryScanHint,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        if (state.wrongCode) ...[
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.deliveryWrongQr,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.coral),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _PackageCard(state: state, editable: false, onChange: (_, _) {}),
      ],
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.state,
    required this.editable,
    required this.onChange,
  });

  final DeliveryState state;
  final bool editable;
  final void Function(String resourceId, int delta) onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final scanned = state.step != DeliveryStep.scan;
    final order = state.order;

    return AppCard(
      tone: scanned ? AppCardTone.success : AppCardTone.normal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                scanned ? Icons.check_circle : Icons.inventory_2_outlined,
                color: scanned ? AppColors.emerald : AppColors.skyBlue,
                size: 28,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.deliveryPackage(order.shortCode, order.zoneName),
                      style: textTheme.titleSmall,
                    ),
                    Text(
                      l10n.deliveryRoute(order.brigadeName),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final line in order.lines)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${line.delivered}/${line.planned} · ${line.name}',
                    style: textTheme.bodyMedium,
                  ),
                ),
                if (editable) ...[
                  IconButton(
                    onPressed: line.delivered > 0
                        ? () => onChange(line.resourceId, -1)
                        : null,
                    tooltip: l10n.counterDecrease(line.name),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  IconButton(
                    onPressed: line.delivered < line.planned
                        ? () => onChange(line.resourceId, 1)
                        : null,
                    tooltip: l10n.counterIncrease(line.name),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.state, required this.editable});

  final DeliveryState state;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DeliveryCubit>();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _EvidenceTile(
              label: l10n.deliverySignature,
              hint: l10n.deliverySignatureHint,
              path: state.signaturePath ?? state.record?.signaturePath,
              icon: Icons.draw_outlined,
              onTap: editable
                  ? () async {
                      final Uint8List? png = await showSignatureSheet(context);
                      if (png != null) await cubit.signed(png);
                    }
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _EvidenceTile(
              label: l10n.deliveryPhoto,
              hint: l10n.deliveryPhotoHint,
              path: state.photoPath ?? state.record?.photoPath,
              icon: Icons.photo_camera_outlined,
              onTap: editable ? cubit.takePhoto : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({
    required this.label,
    required this.hint,
    required this.path,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String hint;
  final String? path;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final done = path != null;
    final file = path == null ? null : File(path!);
    return AppCard(
      tone: done ? AppCardTone.success : AppCardTone.info,
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              height: 72,
              child: file != null && file.existsSync()
                  ? Image.file(file, fit: BoxFit.cover)
                  : ColoredBox(
                      color: AppColors.royalContainer,
                      child: Icon(icon, color: AppColors.white, size: 32),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            done ? '$label ✓' : label,
            style: textTheme.labelMedium?.copyWith(
              color: done ? AppColors.emerald : AppColors.textPrimary,
            ),
          ),
          if (!done)
            Text(
              hint,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Status of the registration and the Blockchain seal.
class _BlockchainCard extends StatelessWidget {
  const _BlockchainCard({
    required this.record,
    required this.onOpenTransaction,
  });

  final DeliveryRecord record;
  final ValueChanged<String> onOpenTransaction;

  static String _short(String hash) {
    final value = hash.startsWith('0x') ? hash : '0x$hash';
    return value.length <= 14
        ? value
        : '${value.substring(0, 6)}…${value.substring(value.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    final (title, tone, icon) = switch (record.status) {
      DeliveryRecordStatus.queued => (
        l10n.deliveryQueued,
        AppCardTone.info,
        Icons.cloud_upload_outlined,
      ),
      DeliveryRecordStatus.registered => (
        l10n.deliveryAnchoring,
        AppCardTone.info,
        Icons.hourglass_top,
      ),
      DeliveryRecordStatus.anchored => (
        l10n.deliveryAnchored,
        AppCardTone.success,
        Icons.verified,
      ),
      DeliveryRecordStatus.anchorFailed => (
        l10n.deliveryAnchorFailed,
        AppCardTone.info,
        Icons.sync_problem,
      ),
      DeliveryRecordStatus.rejected => (
        l10n.deliveryRejected(record.rejection ?? ''),
        AppCardTone.deep,
        Icons.error_outline,
      ),
    };
    final anchored = record.status == DeliveryRecordStatus.anchored;
    final hash = record.transactionHash ?? record.recordHash;

    return Semantics(
      liveRegion: true,
      child: AppCard(
        tone: tone,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: AppSpacing.xxxl,
                  height: AppSpacing.xxxl,
                  decoration: BoxDecoration(
                    color: anchored ? AppColors.emerald : AppColors.royalBlue,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    icon,
                    color: anchored ? AppColors.onAccent : AppColors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          color: anchored ? AppColors.emerald : null,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        l10n.deliveryChain(record.order.shortCode),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hash != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                tone: AppCardTone.deep,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: '${l10n.deliveryHash}: $hash',
                        excludeSemantics: true,
                        child: Text(
                          _short(hash),
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.skyBlue,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    if (record.anchoredAt != null)
                      Text(
                        l10n.deliveryAnchoredAgo(
                          timeAgo(l10n, record.anchoredAt!, DateTime.now()),
                        ),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (record.transactionHash != null)
              TextButton.icon(
                onPressed: () => onOpenTransaction(record.transactionHash!),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(l10n.deliveryTransaction),
              ),
          ],
        ),
      ),
    );
  }
}
