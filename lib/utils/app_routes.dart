import 'package:flutter/material.dart';

/// Central place for all custom page route transitions.
class AppRoutes {
  AppRoutes._();

  // ── Slide up from bottom (article detail, modals) ──────────────
  static PageRoute<T> slideUp<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: const Interval(0, 0.5)),
        );

        // Secondary: current page fades & shrinks slightly when new page pushes
        final secondary = Tween<double>(begin: 1.0, end: 0.93).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOut),
        );

        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: secondary,
            child: SlideTransition(position: slide, child: child),
          ),
        );
      },
    );
  }

  // ── Fade (login → home, modal overlays) ────────────────────────
  static PageRoute<T> fade<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        );
      },
    );
  }

  // ── Slide right (search, settings — feel like a drill-in) ──────
  static PageRoute<T> slideRight<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        final secondary = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.3, 0),
        ).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOut),
        );

        return SlideTransition(
          position: secondary,
          child: SlideTransition(position: slide, child: child),
        );
      },
    );
  }
}
