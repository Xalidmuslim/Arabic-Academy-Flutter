import 'package:flutter/material.dart';

import '../core/performance_probe.dart';

/// A transparent-to-touches, opt-in on-device frame diagnostic panel.
/// Shown only in APKs built with BAYNA_PERF_DIAGNOSTICS=true.
class FrameDiagnosticsOverlay extends StatelessWidget {
  const FrameDiagnosticsOverlay({super.key});

  @override
  Widget build(BuildContext context) => Positioned(
    left: 8,
    right: 8,
    top: 4,
    child: SafeArea(
      child: IgnorePointer(
        child: Center(
          child: ValueListenableBuilder<FramePerformanceReport?>(
            valueListenable: PerformanceProbe.lastReport,
            builder: (context, report, _) => DecoratedBox(
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
                    ? 'Диагностика · прокрути экран (120 кадров)'
                    : '120 Гц: медленных ${report.over120Budget}/${report.frameCount}\n'
                      'UI p95 ${report.uiP95Ms.toStringAsFixed(1)} мс · '
                      'GPU p95 ${report.rasterP95Ms.toStringAsFixed(1)} мс',
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
  );
}
