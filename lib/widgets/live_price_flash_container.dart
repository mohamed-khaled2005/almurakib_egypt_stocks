import 'package:flutter/material.dart';

/// A wrapper widget that flashes a subtle soft green or soft red tint
/// whenever the price updates in real-time, smoothly fading back to normal.
class LivePriceFlashContainer extends StatefulWidget {
  final double price;
  final Widget child;
  final Color baseColor;
  final BorderRadiusGeometry? borderRadius;
  final List<BoxShadow>? boxShadow;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool enabled;

  const LivePriceFlashContainer({
    super.key,
    required this.price,
    required this.child,
    this.baseColor = Colors.white,
    this.borderRadius,
    this.boxShadow,
    this.border,
    this.padding,
    this.margin,
    this.enabled = true,
  });

  @override
  State<LivePriceFlashContainer> createState() =>
      _LivePriceFlashContainerState();
}

class _LivePriceFlashContainerState extends State<LivePriceFlashContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  Color _flashColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(LivePriceFlashContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) return;

    if (oldWidget.price > 0 &&
        widget.price > 0 &&
        widget.price != oldWidget.price) {
      final isUp = widget.price > oldWidget.price;
      // Soft green for gain (#10B981 with 20% opacity), soft red for drop (#EF4444 with 20% opacity)
      _flashColor = isUp ? const Color(0x3310B981) : const Color(0x33EF4444);
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final currentFlash =
            Color.lerp(_flashColor, Colors.transparent, _animation.value) ??
                Colors.transparent;

        return Container(
          margin: widget.margin,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: Color.alphaBlend(currentFlash, widget.baseColor),
            borderRadius: widget.borderRadius,
            boxShadow: widget.boxShadow,
            border: widget.border,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
