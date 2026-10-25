import 'package:flutter/material.dart';

import '../core/performance_probe.dart';

/// Diagnostic-only scroll work, produced-frame cadence and Android vsync.
/// None of these independently proves compositor presentation at 120 FPS.
class FrameDiagnosticsOverlay extends StatelessWidget {
  const FrameDiagnosticsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    const buildLabel = String.fromEnvironment('BAYNA_PERF_BUILD_LABEL');
    const prefix = buildLabel == '' ? '' : '$buildLabel · ';
    return Positioned(
      left: 8,
      right: 8,
      top: 4,
      child: SafeArea(
        child: IgnorePointer(
          child: Center(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                PerformanceProbe.lastReport,
                PerformanceProbe.shadowComparisonMode,
                PerformanceProbe.nativeVsyncHz,
                PerformanceProbe.touchResampling,
              ]),
              builder: (context, _) {
                final refresh = View.of(context).display.refreshRate;
                final display = refresh.isFinite && refresh > 0
                    ? refresh.toStringAsFixed(0) : '—';
                final report = PerformanceProbe.lastReport.value;
                final cadence = report?.cadence;
                final native = PerformanceProbe.nativeVsyncHz.value;
                final fps = cadence?.framesPerSecond.toStringAsFixed(0) ?? '—';
                final period = cadence?.intervalP95Ms.toStringAsFixed(1) ?? '—';
                final vsync = native?.toStringAsFixed(0) ?? '—';
                final mode = PerformanceProbe.shadowComparisonMode.value;
                final sync = PerformanceProbe.touchResampling.value
                    ? 'Ввод СИНХР.' : 'Ввод обычный';
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xE31F2925),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 6,
                    ),
                    child: Text(
                      'Экран Flutter $display Гц · Android vsync $vsync Гц\n'
                      'Кадры Flutter $fps/с · интервал p95 $period мс\n'
                      '${report == null ? 'Прокрути список и дождись остановки' : 'UI p95 ${report.uiP95Ms.toStringAsFixed(1)} мс · Raster p95 ${report.rasterP95Ms.toStringAsFixed(1)} мс'}\n'
                      '${report == null ? '>8,3мс — · >16,7мс —' : '>8,3мс ${report.over120Budget}/${report.frameCount} · >16,7мс ${report.over60Budget}'}\n'
                      '$prefix$sync · Тени: ${mode.label}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10.5, height: 1.2,
                        fontWeight: FontWeight.w600, color: Colors.white,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
