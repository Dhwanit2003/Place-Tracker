import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

enum SlideDirection { forward, backward }

Widget slideTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
    GoRouterState state,
    ) {
  final SlideDirection direction = state.subloc == '/dashboard'
      ? SlideDirection.forward
      : SlideDirection.backward;

  final Offset begin = (direction == SlideDirection.forward)
      ? const Offset(1.0, 0.0) // Forward slide (right to left)
      : const Offset(-1.0, 0.0); // Backward slide (left to right)

  const end = Offset.zero;
  const curve = Curves.easeInOut;

  final tween = Tween<Offset>(begin: begin, end: end).chain(CurveTween(curve: curve));
  final offsetAnimation = animation.drive(tween);

  return SlideTransition(
    position: offsetAnimation,
    child: child,
  );
}
