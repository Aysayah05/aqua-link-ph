import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/gallon_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/gallon_service.dart';
import 'gallon_action_sheet.dart';

class StaffScanner extends StatefulWidget {
  const StaffScanner({super.key});

  @override
  State<StaffScanner> createState() => _StaffScannerState();
}

class _StaffScannerState extends State<StaffScanner> {
  final GallonService _service = GallonService();
  final MobileScannerController _controller = MobileScannerController();
  bool _cameraFailed = false;
  String? _lastCode;
  DateTime _lastScanTime = DateTime.now();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final String? code = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');
    if (code == null || code.isEmpty || code == _lastCode) return;
    if (DateTime.now().difference(_lastScanTime) < const Duration(seconds: 2)) return;
    _lastCode = code;
    _lastScanTime = DateTime.now();
    _openGallonSheet(code);
  }

  Future<void> _openGallonSheet(String code) async {
    try {
      final GallonModel? gallon = await _service.findByQrCode(code);
      if (!mounted) return;
      if (gallon == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No gallon registered with QR "$code".'),
            backgroundColor: AppColors.danger));
        return;
      }
      final String actor = context.read<AuthProvider>().profile?.name ?? 'Staff';
      await showGallonActionSheet(context, gallon, actor, _service);
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lookup failed: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Scan a gallon', style: AppTextStyles.h3),
          Text('Point the camera at the printed QR label on any container.',
              style: AppTextStyles.muted),
        ])),
      ]),
      const SizedBox(height: 14),
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          final double box = ((c.maxWidth > 500 ? 420 : c.maxWidth - 24))
              .clamp(220.0, 460.0)
              .toDouble();
          if (_cameraFailed) {
            return _fallbackPanel(box);
          }
          return Center(
            child: Column(children: [
              Container(
                width: box,
                height: box,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.accent.withOpacity(0.5), width: 2),
                ),
                child: Stack(fit: StackFit.expand, children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !_cameraFailed) setState(() => _cameraFailed = true);
                      });
                      return _fallbackPanel(box, embedded: true);
                    },
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.black54,
                      child: Text('Last scan: ${_lastCode ?? '—'}',
                          style: AppTextStyles.caption.copyWith(color: AppColors.accent)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              SizedBox(width: box, child: _manualEntry()),
            ]),
          );
        }),
      ),
    ]);
  }

  Widget _fallbackPanel(double box, {bool embedded = false}) {
    return Container(
      width: box,
      height: box,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.videocam_off_rounded, size: 40, color: AppColors.textMuted),
        const SizedBox(height: 12),
        Text('Camera unavailable', style: AppTextStyles.h3, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('Grant camera permission in your browser, or use manual entry below — perfect for desktop demos.',
            textAlign: TextAlign.center, style: AppTextStyles.muted),
        if (!embedded) ...[const SizedBox(height: 16), SizedBox(width: box * 0.8, child: _manualEntry())],
      ]),
    );
  }

  Widget _manualEntry() {
    final TextEditingController ctrl = TextEditingController();
    return TextField(
      controller: ctrl,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        hintText: 'GLN-0001',
        labelText: 'Manual lookup (type the gallon code)',
        suffixIcon: IconButton(
          icon: Icon(Icons.arrow_forward_rounded, size: 20, color: Theme.of(context).colorScheme.secondary),
          onPressed: () {
            if (ctrl.text.trim().isEmpty) return;
            _openGallonSheet(ctrl.text.trim());
          },
        ),
      ),
      onSubmitted: (v) {
        if (v.trim().isNotEmpty) _openGallonSheet(v.trim());
      },
    );
  }
}
