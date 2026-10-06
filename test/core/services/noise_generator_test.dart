import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnilife/core/services/noise_generator.dart';

int _u32(Uint8List b, int o) =>
    ByteData.sublistView(b).getUint32(o, Endian.little);
int _u16(Uint8List b, int o) =>
    ByteData.sublistView(b).getUint16(o, Endian.little);
int _s16(Uint8List b, int o) =>
    ByteData.sublistView(b).getInt16(o, Endian.little);

void main() {
  for (final type in NoiseType.values) {
    test('${type.name} noise is a valid looping mono 16-bit WAV', () {
      final wav = NoiseGenerator.noiseWav(type, seconds: 1);

      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
      expect(_u16(wav, 20), 1); // PCM
      expect(_u16(wav, 22), 1); // mono
      expect(_u32(wav, 24), NoiseGenerator.sampleRate);
      expect(_u16(wav, 34), 16);

      final dataLength = _u32(wav, 40);
      expect(dataLength, NoiseGenerator.sampleRate * 2);
      expect(wav.length, 44 + dataLength);
      expect(_u32(wav, 4), 36 + dataLength);

      var peak = 0;
      for (var i = 44; i < wav.length; i += 2) {
        final v = _s16(wav, i).abs();
        if (v > peak) peak = v;
      }
      expect(peak, greaterThan(1000));
      expect(peak, lessThan(32767));
    });
  }

  test('loop seam has no large jump', () {
    for (final type in NoiseType.values) {
      final wav = NoiseGenerator.noiseWav(type, seconds: 1);
      final first = _s16(wav, 44);
      final last = _s16(wav, wav.length - 2);
      // White noise is allowed to be jumpy; filtered noise must be smooth.
      if (type != NoiseType.white) {
        expect((first - last).abs(), lessThan(8000), reason: type.name);
      }
    }
  });

  test('noise is deterministic for a seed and differs between colours', () {
    final a = NoiseGenerator.noiseWav(NoiseType.pink, seconds: 1);
    final b = NoiseGenerator.noiseWav(NoiseType.pink, seconds: 1);
    final c = NoiseGenerator.noiseWav(NoiseType.brown, seconds: 1);
    expect(a, b);
    expect(a, isNot(c));
  });

  test('chime is a short decaying tone', () {
    final wav = NoiseGenerator.chimeWav(seconds: 1);
    expect(_u32(wav, 40), NoiseGenerator.sampleRate * 2);
    // Starts silent (attack), is louder early than at the very end.
    expect(_s16(wav, 44).abs(), lessThan(200));
    var early = 0;
    var late = 0;
    for (var i = 0; i < 2000; i++) {
      early = early < _s16(wav, 44 + 2 * (500 + i)).abs()
          ? _s16(wav, 44 + 2 * (500 + i)).abs()
          : early;
      final j = wav.length - 4000 + 2 * i;
      late = late < _s16(wav, j).abs() ? _s16(wav, j).abs() : late;
    }
    expect(early, greaterThan(late));
  });
}
