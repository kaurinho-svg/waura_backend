import 'package:flutter/material.dart';

class ScannerOverlay extends StatefulWidget {
  final bool isScanning;
  final Widget child;

  const ScannerOverlay({
    super.key,
    required this.isScanning,
    required this.child,
  });

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear)
    );

    if (widget.isScanning) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ScannerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning != oldWidget.isScanning) {
      if (widget.isScanning) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        
        if (widget.isScanning)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3), // Dim background slightly
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final top = constraints.maxHeight * _animation.value;
                      return Stack(
                        children: [
                           // Scan Line
                           Positioned(
                             top: top,
                             left: 0,
                             right: 0,
                             child: Container(
                               height: 2,
                               decoration: BoxDecoration(
                                 boxShadow: [
                                   BoxShadow(
                                     color: Colors.cyanAccent.withOpacity(0.5),
                                     blurRadius: 10,
                                     spreadRadius: 2,
                                   )
                                 ],
                                 gradient: const LinearGradient(
                                   colors: [Colors.transparent, Colors.cyanAccent, Colors.transparent],
                                 ),
                               ),
                             ),
                           ),
                           // Gradient Trail
                           Positioned(
                             top: top - 60,
                             left: 0,
                             right: 0,
                             height: 60,
                             child: Container(
                               decoration: BoxDecoration(
                                 gradient: LinearGradient(
                                   begin: Alignment.bottomCenter,
                                   end: Alignment.topCenter,
                                   colors: [
                                     Colors.cyanAccent.withOpacity(0.3),
                                     Colors.transparent
                                   ],
                                 ),
                               ),
                             ),
                           ),
                        ],
                      );
                    }
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
