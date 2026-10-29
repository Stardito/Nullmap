import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_color_utilities/material_color_utilities.dart'
    show QuantizerCelebi, QuantizerResult, Score;
import 'package:material_ui/material_ui.dart';

/// 从图片字节里按 Material You（Monet）算法取一个主题色。
///
/// 失败（解码失败、全透明、量化异常）时返回 null，调用方退回主题主色。
Future<Color?> monetColorFromImage(Uint8List bytes) async {
  try {
    final ui.Codec codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 64,
      targetHeight: 64,
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ByteData? raw = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    frame.image.dispose();
    codec.dispose();
    if (raw == null) {
      return null;
    }

    final List<int> pixels = <int>[];
    for (int offset = 0; offset + 3 < raw.lengthInBytes; offset += 4) {
      final int alpha = raw.getUint8(offset + 3);
      if (alpha < 128) {
        continue;
      }
      final int red = raw.getUint8(offset);
      final int green = raw.getUint8(offset + 1);
      final int blue = raw.getUint8(offset + 2);
      pixels.add(0xFF000000 | (red << 16) | (green << 8) | blue);
    }
    if (pixels.isEmpty) {
      return null;
    }

    final QuantizerResult quantized = await QuantizerCelebi().quantize(
      pixels,
      16,
    );
    final List<int> ranked = Score.score(quantized.colorToCount, desired: 1);
    if (ranked.isEmpty) {
      return null;
    }
    return Color(ranked.first);
  } on Exception {
    return null;
  }
}
