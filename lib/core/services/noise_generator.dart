import 'dart:math' as math;
import 'dart:typed_data';

enum NoiseType { white, pink, brown }

/// Generates ambient noise and short tones as 16-bit mono PCM WAV bytes, so
/// focus audio works offline and on every platform without bundled assets.
abstract final class NoiseGenerator {
  static const sampleRate = 22050;

  /// Seamlessly loopable noise of [seconds] length.
  static Uint8List noiseWav(
    NoiseType type, {
    double seconds = 6,
    int seed = 7,
  }) {
    final n = (seconds * sampleRate).round();
    // Extra tail used to cross-fade the end into the start, so the loop
    // point of the filtered noise has no audible click.
    final fade = (0.25 * sampleRate).round();
    final raw = _noise(type, n + fade, math.Random(seed));

    final out = Float64List(n);
    for (var i = 0; i < n; i++) {
      out[i] = raw[i];
    }
    for (var i = 0; i < fade; i++) {
      final w = i / fade;
      out[i] = raw[i] * w + raw[n + i] * (1 - w);
    }
    _normalize(out, 0.5);
    return _toWav(out);
  }

  /// A soft bell/gong: a few inharmonic partials with exponential decay.
  static Uint8List chimeWav({double seconds = 2.4, double baseHz = 330}) {
    final n = (seconds * sampleRate).round();
    final out = Float64List(n);
    const partials = [
      (1.0, 1.0, 1.6),
      (2.0, 0.5, 2.4),
      (2.76, 0.35, 3.2),
      (5.4, 0.15, 5.0),
    ];
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      var v = 0.0;
      for (final (ratio, amp, decay) in partials) {
        v +=
            amp *
            math.sin(2 * math.pi * baseHz * ratio * t) *
            math.exp(-decay * t);
      }
      // 8 ms attack to avoid a click at the start.
      final attack = math.min(1.0, t / 0.008);
      out[i] = v * attack;
    }
    _normalize(out, 0.6);
    return _toWav(out);
  }

  static Float64List _noise(NoiseType type, int length, math.Random rng) {
    final out = Float64List(length);
    switch (type) {
      case NoiseType.white:
        for (var i = 0; i < length; i++) {
          out[i] = rng.nextDouble() * 2 - 1;
        }
      case NoiseType.pink:
        // Paul Kellet's economy pink filter.
        var b0 = 0.0,
            b1 = 0.0,
            b2 = 0.0,
            b3 = 0.0,
            b4 = 0.0,
            b5 = 0.0,
            b6 = 0.0;
        for (var i = 0; i < length; i++) {
          final white = rng.nextDouble() * 2 - 1;
          b0 = 0.99886 * b0 + white * 0.0555179;
          b1 = 0.99332 * b1 + white * 0.0750759;
          b2 = 0.96900 * b2 + white * 0.1538520;
          b3 = 0.86650 * b3 + white * 0.3104856;
          b4 = 0.55000 * b4 + white * 0.5329522;
          b5 = -0.7616 * b5 - white * 0.0168980;
          out[i] = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362;
          b6 = white * 0.115926;
        }
      case NoiseType.brown:
        var last = 0.0;
        for (var i = 0; i < length; i++) {
          final white = rng.nextDouble() * 2 - 1;
          last = (last + 0.02 * white) / 1.02;
          out[i] = last * 3.5;
        }
    }
    return out;
  }

  static void _normalize(Float64List data, double peakTarget) {
    var peak = 0.0;
    for (final v in data) {
      if (v.abs() > peak) peak = v.abs();
    }
    if (peak == 0) return;
    final gain = peakTarget / peak;
    for (var i = 0; i < data.length; i++) {
      data[i] *= gain;
    }
  }

  static Uint8List _toWav(Float64List samples) {
    final dataLength = samples.length * 2;
    final bytes = ByteData(44 + dataLength);
    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLength, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    bytes.setUint32(40, dataLength, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      bytes.setInt16(44 + i * 2, v, Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
