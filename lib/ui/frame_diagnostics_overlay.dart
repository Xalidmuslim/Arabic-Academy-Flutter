import 'package:flutter/material.dart';

import '../core/performance_probe.dart';

/// A transparent-to-touches, opt-in on-device frame diagnostic panel.
/// Shown only in APKs built with BAYNA_PERF_DIAGNOSTICS=true.
class FrameDiagnosticsOverlay extends StatelessWidget {
  const FrameDiagnosticsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    // Engine reported Hz, not measured delivered FPS. The former fixed
    // "120 Hz" header was just a comparison against an 8.33 ms budget.
    final refresh = View.of(context).display.refreshRate;
    final rate = refresh.isFinite && refresh > 0
        ? refresh.toStringAsFixed(0) : '—';
    return Positioned(
    left: 8,
    right: 8,
    top: 4,
    child: SafeArea(
      child: IgnorePointer(
        child: Center(
          child: ValueListenableBuilder<FramePerformanceReport?>(
            valueListenable: PerformanceProbe.lastReport,
            builder: (context, report, _) => ValueListenableBuilder<bool>(
              valueListenable: PerformanceProbe.silhouetteBlurEnabled,
              builder: (context, blur, _) => DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xE31F2925),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                child: Text(
                  report == null
                    ? 'Экран Flutter $rate Гц · прокрути 120 кадров\n'
                      'Тени карточек и рисунков: ${blur ? "ВКЛ" : "ВЫКЛ"}'
                    : 'Экран Flutter $rate Гц · >8,3мс '
                      '${report.over120Budget}/${report.frameCount}\n'
                      'UI p95 ${report.uiP95Ms.toStringAsFixed(1)} мс · '
                      'GPU p95 ${report.rasterP95Ms.toStringAsFixed(1)} мс '
                      '· >16,7мс ${report.over60Budget}\n'
                      'Тени карточек и рисунков: ${blur ? "ВКЛ" : "ВЫКЛ"}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}
