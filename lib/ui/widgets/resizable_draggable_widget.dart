import 'dart:math';
import 'package:flutter/material.dart';

class ResizableDraggableWidget extends StatefulWidget {
  final Widget child;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Function(Matrix4) onTransform;
  final Matrix4 initialTransform;

  const ResizableDraggableWidget({
    super.key,
    required this.child,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    required this.onTransform,
    required this.initialTransform,
  });

  @override
  State<ResizableDraggableWidget> createState() =>
      _ResizableDraggableWidgetState();
}

class _ResizableDraggableWidgetState extends State<ResizableDraggableWidget> {
  late Matrix4 _transform;
  double _baseScaleFactor = 1.0;
  double _scaleFactor = 1.0;
  double _baseRotation = 0.0;
  double _rotation = 0.0;
  Offset _baseTranslation = Offset.zero;
  Offset _translation = Offset.zero;

  @override
  void initState() {
    super.initState();
    _transform = widget.initialTransform;
    // Decompose initial transform to set internal state if needed
    // For simplicity, we just track deltas from identity or accumulate
    // But since we receive initialTransform, ideally we should respect it.
    // However, gesture detectors usually give deltas.
    // Let's use a simpler approach: wrapping the child in a MatrixGestureDetector-like logic
    // or just using InteractiveViewer (too restrictive) or custom GestureDetector.
  }

  // Simplified custom gesture handling for Rotate+Scale+Translate
  void _onScaleStart(ScaleStartDetails details) {
    widget.onTap();
    _baseScaleFactor = _scaleFactor;
    _baseRotation = _rotation;
    _baseTranslation = _translation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scaleFactor = _baseScaleFactor * details.scale;
      _rotation = _baseRotation + details.rotation;
      _translation = _baseTranslation + details.focalPointDelta;
      
      // Update the transform matrix
      _transform = Matrix4.identity()
        ..translate(_translation.dx, _translation.dy)
        ..rotateZ(_rotation)
        ..scale(_scaleFactor);
    });
    widget.onTransform(_transform);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          // We apply the transform to the child
          Transform(
            transform: _transform,
            alignment: Alignment.center,
            child: GestureDetector(
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onTap: widget.onTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // The actual content (image)
                  Container(
                    decoration: widget.isSelected
                        ? BoxDecoration(
                            border: Border.all(color: Colors.blue, width: 2),
                          )
                        : null,
                    child: widget.child,
                  ),
                  
                  // Delete button (visible only when selected)
                  if (widget.isSelected)
                    Positioned(
                      top: -12,
                      right: -12,
                      child: GestureDetector(
                        onTap: widget.onDelete,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red,
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
