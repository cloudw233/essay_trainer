import 'package:flutter/material.dart';

/// Small, reusable building blocks for the 文衡 visual language.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: border == null ? null : Border.fromBorderSide(border!),
      ),
      child: child,
    );
  }
}

/// The project app mark, drawn from the compact icon geometry.
///
/// The icon assets exist under `assets/icon/`, but release builds on the
/// current emulator did not composite bitmap images inside the large app bar.
/// This vector version uses the same compact 32-unit geometry and brand
/// colours, so the mark stays crisp at 34dp without image decoding.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: const _AppMarkPainter(),
      ),
    );
  }
}

class _AppMarkPainter extends CustomPainter {
  const _AppMarkPainter();

  static const Color _paper = Color(0xFFF6F1E7);
  static const Color _ink = Color(0xFF243A2F);
  static const Color _amber = Color(0xFFC96A24);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 32.0;
    final paper = Paint()
      ..color = _paper
      ..isAntiAlias = true;
    final ink = Paint()
      ..color = _ink
      ..isAntiAlias = true;
    final amber = Paint()
      ..color = _amber
      ..isAntiAlias = true;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, 32 * scale, 32 * scale),
        Radius.circular(7.2 * scale),
      ),
      paper,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6.8 * scale, 10.1 * scale, 15.6 * scale, 3.2 * scale),
        Radius.circular(0.7 * scale),
      ),
      ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8.2 * scale, 19.2 * scale, 15 * scale, 3.2 * scale),
        Radius.circular(0.7 * scale),
      ),
      ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(18.8 * scale, 5.9 * scale, 2.8 * scale, 20 * scale),
        Radius.circular(1.4 * scale),
      ),
      amber,
    );

    final diamond = Path()
      ..moveTo(20.2 * scale, 3.7 * scale)
      ..lineTo(23.1 * scale, 6.8 * scale)
      ..lineTo(20.2 * scale, 9.9 * scale)
      ..lineTo(17.3 * scale, 6.8 * scale)
      ..close();
    canvas.drawPath(diamond, amber);
  }

  @override
  bool shouldRepaint(covariant _AppMarkPainter oldDelegate) => false;
}

/// A tiny seal-like mark used next to the product name.
class InkSeal extends StatelessWidget {
  const InkSeal({super.key, this.size = 44, this.character = '衡'});

  final double size;
  final String character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        character,
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

/// A fixed-height loading placeholder shared by data-driven pages.
///
/// Keeping the height stable avoids the content jump between loading and the
/// loaded/empty state. It intentionally stays a simple progress indicator;
/// the app does not need per-page skeletons to communicate progress.
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.height = 240, this.label});

  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (label != null) ...[
              const SizedBox(height: 12),
              Text(
                label!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A compact status pill for a label like "动态取色 · 已启用".
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.icon,
    this.background,
    this.foreground,
  });

  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = foreground ?? scheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background ?? scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A severity dot that takes its colour from [AppSemanticColors].
class SeverityDot extends StatelessWidget {
  const SeverityDot({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
