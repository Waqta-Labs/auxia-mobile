import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Camera preview that reads the QR of the package (A_08, step 1).
class QrScannerView extends StatefulWidget {
  const QrScannerView({super.key, required this.onDetect});

  final ValueChanged<String> onDetect;

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScannerFrame(
      child: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue;
            if (value != null && value.isNotEmpty) {
              widget.onDetect(value);
              return;
            }
          }
        },
        errorBuilder: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              AppLocalizations.of(context).deliveryCameraUnavailable,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }
}

/// Square viewfinder of the mockup: lime corners and a scan line.
class ScannerFrame extends StatelessWidget {
  const ScannerFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: ColoredBox(
          color: AppColors.surfaceDeep,
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              const IgnorePointer(child: CustomPaint(painter: _FramePainter())),
            ],
          ),
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.lime
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const inset = 20.0;
    const length = 32.0;
    final r = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );
    final corners = [
      (r.topLeft, const Offset(length, 0), const Offset(0, length)),
      (r.topRight, const Offset(-length, 0), const Offset(0, length)),
      (r.bottomLeft, const Offset(length, 0), const Offset(0, -length)),
      (r.bottomRight, const Offset(-length, 0), const Offset(0, -length)),
    ];
    for (final (corner, horizontal, vertical) in corners) {
      canvas
        ..drawLine(corner, corner + horizontal, paint)
        ..drawLine(corner, corner + vertical, paint);
    }
    final line = Paint()
      ..color = AppColors.lime
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(r.left + 8, size.height / 2),
      Offset(r.right - 8, size.height / 2),
      line,
    );
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => false;
}
