import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/services.dart' show StandardMessageCodec;
import 'package:material_ui/material_ui.dart';

/// 地图页。
///
/// Android 上使用原生高德 3D 地图（PlatformView），其他平台暂时用
/// [CustomPaint] 画占位网格与标记点。
class MapPage extends StatelessWidget {
  const MapPage({super.key});

  static const List<_Marker> _markers = [
    _Marker('节点 A', Offset(0.28, 0.32), Color(0xFF2E7D32)),
    _Marker('节点 B', Offset(0.62, 0.24), Color(0xFFEF6C00)),
    _Marker('节点 C', Offset(0.46, 0.62), Color(0xFF1565C0)),
  ];

  /// 与 android/.../AmapView.kt 注册的 viewType 一致。
  static const String amapViewType = 'io.stardito.nullmap/amap';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Stack(
      children: [
        Positioned.fill(
          child: Platform.isAndroid
              ? const AndroidView(
                  viewType: amapViewType,
                  creationParams: <String, Object>{},
                  creationParamsCodec: StandardMessageCodec(),
                )
              : const _MapCanvas(),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 12,
          child: SearchBar(
            hintText: '搜索位置或节点',
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(1),
            trailing: [
              IconButton(
                tooltip: '图层',
                icon: const Icon(Icons.layers_outlined),
                onPressed: () => _toast(context, '图层切换暂未开放'),
              ),
            ],
            onChanged: (_) {},
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.near_me, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('当前位置', style: theme.textTheme.titleMedium),
                        const Spacer(),
                        Text(
                          '3 个节点',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _markers
                          .map(
                            (m) => ActionChip(
                              avatar: Icon(
                                Icons.circle,
                                size: 12,
                                color: m.color,
                              ),
                              label: Text(m.label),
                              onPressed: () =>
                                  _toast(context, '${m.label} 详情待接入'),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

class _Marker {
  const _Marker(this.label, this.position, this.color);

  final String label;
  final Offset position;
  final Color color;
}

class _MapCanvas extends StatelessWidget {
  const _MapCanvas();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: scheme.surfaceContainerLow),
            ),
            Positioned.fill(child: CustomPaint(painter: _GridPainter(scheme))),
            for (final _Marker marker in MapPage._markers)
              Positioned(
                left: constraints.maxWidth * marker.position.dx,
                top: constraints.maxHeight * marker.position.dy,
                child: _Pin(marker: marker, scheme: scheme),
              ),
          ],
        );
      },
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.marker, required this.scheme});

  final _Marker marker;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(-16, -32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: 32, color: marker.color),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text(marker.label, style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.scheme);

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint grid = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    const double step = 48;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // 一条斜向主干道，纯装饰。
    final Paint road = Paint()
      ..color = scheme.primary.withValues(alpha: 0.18)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.85),
      Offset(size.width * 0.85, size.height * 0.15),
      road,
    );

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.45),
      math.min(size.width, size.height) * 0.35,
      Paint()
        ..color = scheme.primary.withValues(alpha: 0.06)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.scheme != scheme;
}
