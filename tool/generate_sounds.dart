// Synthesizes the pencil-on-paper loop (assets/sounds/pencil.wav): filtered
// noise for graphite, slow wobble for the hand, sparse crackle for the paper
// tooth. The end crossfades into the start, so it loops without a click.
//
// Run from the project root:
//   dart run tool/generate_sounds.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const rate = 22050;
const seconds = 1.6;
const fade = 0.25;

void main() {
  final rnd = math.Random(7);
  final total = ((seconds + fade) * rate).round();
  final raw = Float64List(total);

  // Graphite: white noise, high-passed (~900 Hz) then softened (~6 kHz).
  double hpPrevIn = 0, hpPrevOut = 0, lp = 0;
  final hpA = 1 / (1 + 2 * math.pi * 900 / rate);
  final lpA = 1 - math.exp(-2 * math.pi * 6000 / rate);
  // The hand: slow random wobble in pressure (smoothed noise, ~6 Hz).
  double wobble = 0.6, wobbleTarget = 0.6;
  for (var i = 0; i < total; i++) {
    final x = rnd.nextDouble() * 2 - 1;
    final hp = hpA * (hpPrevOut + x - hpPrevIn);
    hpPrevIn = x;
    hpPrevOut = hp;
    lp += lpA * (hp - lp);

    if (i % (rate ~/ 6) == 0) wobbleTarget = 0.45 + rnd.nextDouble() * 0.55;
    wobble += (wobbleTarget - wobble) * 0.0015;

    // Paper tooth: rare short grains on top.
    var grain = 0.0;
    if (rnd.nextDouble() < 0.0025) grain = (rnd.nextDouble() * 2 - 1) * 1.6;
    raw[i] = lp * wobble + grain * 0.35;
  }

  // Loop: crossfade the tail over the head.
  final n = (seconds * rate).round();
  final f = (fade * rate).round();
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    out[i] = raw[i];
  }
  for (var i = 0; i < f; i++) {
    final t = i / f;
    out[i] = raw[i] * math.sin(t * math.pi / 2) + raw[n + i] * math.cos(t * math.pi / 2);
  }

  // Normalize to -6 dBFS; quiet by design, the app sets the volume.
  final peak = out.fold<double>(0, (m, v) => math.max(m, v.abs()));
  final gain = 0.5 / peak;
  final pcm = Int16List(n);
  for (var i = 0; i < n; i++) {
    pcm[i] = (out[i] * gain * 32767).round().clamp(-32768, 32767);
  }

  final data = pcm.buffer.asUint8List();
  final header = ByteData(44);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + data.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, rate, Endian.little);
  header.setUint32(28, rate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, data.length, Endian.little);

  final file = File('assets/sounds/pencil.wav')..createSync(recursive: true);
  file.writeAsBytesSync([...header.buffer.asUint8List(), ...data]);
  stdout.writeln('wrote ${file.path} (${file.lengthSync()} bytes)');
}
