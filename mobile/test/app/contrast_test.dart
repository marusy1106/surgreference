import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:surgreference/app/theme/theme.dart';

/// WCAG 2.1: контраст текста ≥ 4.5:1 в обеих темах (docs/08-design.md, 8.4).
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  for (final (name, c) in [('dark', SrColors.dark), ('light', SrColors.light)]) {
    group('$name theme', () {
      final backgrounds = {'bg': c.bg, 'surface': c.surface, 'surface2': c.surface2};
      final foregrounds = {
        'text': c.text,
        'textMuted': c.textMuted,
        'accent': c.accent,
        'success': c.success,
        'error': c.error,
        'warning': c.warning,
      };
      for (final MapEntry(key: fg, value: fgColor) in foregrounds.entries) {
        for (final MapEntry(key: bg, value: bgColor) in backgrounds.entries) {
          test('$fg on $bg ≥ 4.5', () => expect(contrast(fgColor, bgColor), greaterThanOrEqualTo(4.5)));
        }
      }

      // Маркер — не текст: для графических элементов WCAG 1.4.11 требует 3:1.
      test('marker on every background ≥ 3', () {
        for (final bgColor in backgrounds.values) {
          expect(contrast(c.marker, bgColor), greaterThanOrEqualTo(3));
        }
      });

      test('onAccent on accent ≥ 4.5', () => expect(contrast(c.onAccent, c.accent), greaterThanOrEqualTo(4.5)));

      test('status text on its tinted background ≥ 4.5', () {
        for (final tone in [c.success, c.error, c.warning, c.accent]) {
          final tinted = Color.alphaBlend(tone.withValues(alpha: 0.14), c.surface);
          expect(contrast(tone, tinted), greaterThanOrEqualTo(4.5), reason: '$tone');
          expect(contrast(c.text, tinted), greaterThanOrEqualTo(4.5), reason: '$tone');
        }
      });
    });
  }

  group('aura cards', () {
    for (final aura in Aura.values) {
      test('${aura.name}: white ink and muted ink at the brightest point ≥ 4.5', () {
        expect(contrast(AuraInk.ink, aura.peak), greaterThanOrEqualTo(4.5));
        expect(contrast(Color.alphaBlend(AuraInk.inkMuted, aura.peak), aura.peak), greaterThanOrEqualTo(4.5));
      });
    }
  });

  test('unknown palette token falls back to a valid aura', () {
    expect(Aura.fromToken('dermatology'), Aura.surgery);
    expect(Aura.fromToken('pharmacology'), Aura.pharmacology);
  });
}
