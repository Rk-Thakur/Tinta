import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// The soft paper scratch while drawing: a native loop whose volume follows
/// the speed of the stroke, silent when the pen rests.
class PencilSound {
  PencilSound();

  static const _channel = MethodChannel('tinta/sound');
  static const asset = 'assets/sounds/pencil.wav';

  /// Speed (logical px per ms) that plays at full volume.
  static const _fullSpeed = 1.6;
  static const _maxVolume = 0.55;

  bool enabled = true;

  Timer? _tick;
  double _target = 0;
  double _volume = 0;
  double _sent = -1;
  Duration? _lastMove;
  DateTime _lastMoveAt = DateTime(0);
  bool _playing = false;

  void start() {
    if (!enabled || _playing) return;
    _playing = true;
    _target = 0;
    _volume = 0;
    _lastMove = null;
    _call('start', {'asset': asset});
    // Ease towards the target and fade out when the pen stops moving.
    _tick = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (DateTime.now().difference(_lastMoveAt).inMilliseconds > 90) {
        _target = 0;
      }
      _volume += (_target - _volume) * 0.45;
      if ((_volume - _sent).abs() > 0.02) {
        _sent = _volume;
        _call('volume', {'volume': _volume});
      }
    });
  }

  /// A pen move of [distance] logical px at event time [time].
  void move(double distance, Duration time) {
    if (!_playing) return;
    final last = _lastMove;
    _lastMove = time;
    _lastMoveAt = DateTime.now();
    if (last == null) return;
    final ms = math.max((time - last).inMicroseconds / 1000, 1);
    final speed = distance / ms;
    _target = (speed / _fullSpeed).clamp(0.0, 1.0) * _maxVolume;
  }

  void stop() {
    if (!_playing) return;
    _playing = false;
    _tick?.cancel();
    _tick = null;
    _sent = -1;
    _call('stop');
  }

  void dispose() => stop();

  static void _call(String method, [Object? args]) {
    _channel.invokeMethod<void>(method, args).catchError((_) {});
  }
}
