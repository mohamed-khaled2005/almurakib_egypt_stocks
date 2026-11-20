import 'package:flutter/material.dart';

class AppLoadingWidget extends StatefulWidget {
  final bool animate;
  final double scale;

  const AppLoadingWidget({
    super.key,
    this.animate = true,
    this.scale = 1.0,
  });

  @override
  State<AppLoadingWidget> createState() => _AppLoadingWidgetState();
}

class _AppLoadingWidgetState extends State<AppLoadingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _pulse = Tween<double>(begin: 0.98, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Concentric Rings with Logo (Matches Image 5)
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final scale = widget.animate ? _pulse.value : 1.0;
              return Transform.scale(
                scale: scale * widget.scale,
                child: child,
              );
            },
            child: SizedBox(
              width: 270,
              height: 270,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Ring 3
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFDE8E8).withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                    ),
                  ),

                  // Middle Ring 2
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFDE8E8).withValues(alpha: 0.75),
                        width: 1.2,
                      ),
                    ),
                  ),

                  // Inner Ring 1
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFDE8E8),
                        width: 1.3,
                      ),
                    ),
                  ),

                  // Center Logo
                  Image.asset(
                    'assets/images/Icon.png',
                    width: 90,
                    height: 90,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Title: مراقب الاسهم المصرية
          const Text(
            'مراقب الاسهم المصرية',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          // Subtitle: Almurakib.com
          const Text(
            'Almurakib.com',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
