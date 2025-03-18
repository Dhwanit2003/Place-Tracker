import 'package:flutter/material.dart';

class SlidingContent extends StatelessWidget {
  final Widget child;
  final bool showContent;

  const SlidingContent({
    Key? key,
    required this.child,
    required this.showContent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
      child: child,
    );
  }
}
