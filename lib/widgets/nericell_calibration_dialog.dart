import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:road_anomaly_collector/services/ml_inference_service.dart';
import 'package:road_anomaly_collector/services/nericell_service.dart';
import 'package:road_anomaly_collector/services/sensor_service.dart';

/// Modal dialog for Pre-Drive Nericell Euler-Rodrigues Orientation Calibration.
class NericellCalibrationDialog extends StatefulWidget {
  const NericellCalibrationDialog({super.key});

  @override
  State<NericellCalibrationDialog> createState() =>
      _NericellCalibrationDialogState();
}

class _NericellCalibrationDialogState extends State<NericellCalibrationDialog> {
  bool _isCalibrating = false;
  double _progress = 0.0;
  String _statusMessage = 'Place phone in vehicle mount while parked.';
  bool _isSuccess = false;
  bool _hasFailed = false;

  StreamSubscription<CombinedSensorReading>? _calibrationSub;

  @override
  void dispose() {
    _calibrationSub?.cancel();
    super.dispose();
  }

  void _startCalibration() {
    setState(() {
      _isCalibrating = true;
      _progress = 0.0;
      _isSuccess = false;
      _hasFailed = false;
      _statusMessage = 'Sampling steady gravity (100 Hz)... Hold steady.';
    });

    NericellService().reset();
    SensorService().ensureListening();

    _calibrationSub = SensorService().sensorStream.listen((reading) {
      final prog = NericellService().addCalibrationSample(
        reading.accelX,
        reading.accelY,
        reading.accelZ,
        targetSamples: 300, // 3 seconds at 100Hz
      );

      setState(() {
        _progress = prog;
      });

      if (prog >= 1.0) {
        _calibrationSub?.cancel();
        _finalize();
      }
    });
  }

  void _finalize() {
    final success = NericellService().finalizeCalibration();
    if (success) {
      // Propagate rotation matrix to ML Worker Isolate
      MlInferenceService().updateRotationMatrix(NericellService().rotationMatrix);
      HapticFeedback.mediumImpact();
      setState(() {
        _isCalibrating = false;
        _isSuccess = true;
        _statusMessage = 'Calibration complete! Gravity aligned to vehicle vertical.';
      });
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _isCalibrating = false;
        _hasFailed = true;
        _statusMessage = 'Calibration failed: excessive movement detected. Ensure car is parked and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF161618),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      CupertinoIcons.compass,
                      color: CupertinoColors.activeBlue,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Mount Self-Calibration',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  child: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: CupertinoColors.systemGrey,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Nericell Euler-Rodrigues algorithm virtually reorients arbitrary phone tilt to true vehicular coordinates (vertical gravity [0, 0, 1]), rendering pothole & bump detection invariant to mounting angle.',
              style: TextStyle(
                color: CupertinoColors.systemGrey,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Progress Bar / Status Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isSuccess
                      ? CupertinoColors.activeGreen.withOpacity(0.4)
                      : (_hasFailed
                          ? CupertinoColors.systemRed.withOpacity(0.4)
                          : CupertinoColors.white.withOpacity(0.08)),
                ),
              ),
              child: Column(
                children: [
                  if (_isCalibrating) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 8,
                        color: CupertinoColors.white.withOpacity(0.1),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: _progress,
                            child: Container(color: CupertinoColors.activeBlue),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Icon(
                        _isSuccess
                            ? CupertinoIcons.check_mark_circled_solid
                            : (_hasFailed
                                ? CupertinoIcons.exclamationmark_circle_fill
                                : CupertinoIcons.info_circle_fill),
                        color: _isSuccess
                            ? CupertinoColors.activeGreen
                            : (_hasFailed
                                ? CupertinoColors.systemRed
                                : CupertinoColors.activeBlue),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _isSuccess
                                ? CupertinoColors.activeGreen
                                : (_hasFailed
                                    ? CupertinoColors.systemRed
                                    : CupertinoColors.white),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Buttons
            if (!_isCalibrating)
              CupertinoButton.filled(
                onPressed: _startCalibration,
                child: Text(_isSuccess ? 'Recalibrate' : 'Start 3s Calibration'),
              )
            else
              CupertinoButton(
                color: CupertinoColors.systemGrey.withOpacity(0.2),
                onPressed: null,
                child: const Text('Calibrating...'),
              ),
          ],
        ),
      ),
    );
  }
}
