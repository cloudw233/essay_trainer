import 'package:flutter/widgets.dart';

/// Exposes whether the OS supplied a Material You wallpaper palette.
///
/// Settings uses this to tell the user whether they are seeing dynamic colours
/// or the ink-green fallback.
class DynamicColorScope extends InheritedWidget {
  const DynamicColorScope({
    super.key,
    required this.active,
    required super.child,
  });

  final bool active;

  static bool isActiveOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<DynamicColorScope>()
            ?.active ??
        false;
  }

  @override
  bool updateShouldNotify(DynamicColorScope oldWidget) {
    return active != oldWidget.active;
  }
}
