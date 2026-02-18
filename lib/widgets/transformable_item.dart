import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class TransformData {
  Offset position;
  double scale;
  double rotation; // radians
  TransformData({this.position = Offset.zero, this.scale = 1.0, this.rotation = 0});
}

class TransformableItem extends StatefulWidget {
  final Widget child;
  final TransformData data;
  final ValueChanged<TransformData>? onChanged;
  final VoidCallback? onDelete;
  final bool selected;

  const TransformableItem({
    super.key,
    required this.child,
    required this.data,
    this.onChanged,
    this.onDelete,
    this.selected = false,
  });

  @override
  State<TransformableItem> createState() => _TransformableItemState();
}

class _TransformableItemState extends State<TransformableItem> {
  late TransformData t;
  double _baseScale = 1;
  double _baseRotation = 0;

  @override
  void initState() {
    super.initState();
    t = TransformData(
      position: widget.data.position,
      scale: widget.data.scale,
      rotation: widget.data.rotation,
    );
  }

  void _notify() => widget.onChanged?.call(TransformData(
    position: t.position,
    scale: t.scale,
    rotation: t.rotation,
  ));

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (signal) {
        if (signal is PointerScrollEvent) {
          final delta = signal.scrollDelta.dy;
          t = TransformData(
            position: t.position,
            scale: (t.scale * (1 - delta * 0.001)).clamp(0.2, 8.0),
            rotation: t.rotation,
          );
          setState(_notify);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onScaleStart: (d) {
          _baseScale = t.scale;
          _baseRotation = t.rotation;
        },
        onScaleUpdate: (d) {
          setState(() {
            t = TransformData(
              position: t.position + d.focalPointDelta,
              scale: (_baseScale * d.scale).clamp(0.2, 8.0),
              rotation: _baseRotation + d.rotation,
            );
          });
          _notify();
        },
        onDoubleTap: () {
          setState(() => t = TransformData());
          _notify();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Transform(
              transform: Matrix4.identity()
                ..translate(t.position.dx, t.position.dy)
                ..rotateZ(t.rotation)
                ..scale(t.scale),
              alignment: Alignment.center,
              child: widget.child,
            ),
            if (widget.selected)
              Positioned(
                right: -4,
                top: -4,
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onDelete,
                ),
              ),
          ],
        ),
      ),
    );
  }
}