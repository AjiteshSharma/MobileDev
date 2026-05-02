import 'package:flutter/material.dart';

class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offset = const Offset(0, 0.05),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final total = (duration + delay).inMilliseconds.toDouble();
    final delayPortion = total <= 0 ? 0.0 : delay.inMilliseconds / total;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration + delay,
      curve: Curves.linear,
      builder: (context, value, _) {
        final denominator = (1 - delayPortion).clamp(0.0001, 1.0);
        final local = ((value - delayPortion) / denominator).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(local);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(
              offset.dx * (1 - eased) * 80,
              offset.dy * (1 - eased) * 80,
            ),
            child: child,
          ),
        );
      },
    );
  }
}
