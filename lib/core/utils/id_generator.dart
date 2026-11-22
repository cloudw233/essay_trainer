import 'dart:math';

final Random _random = Random.secure();

/// Generates a collision-resistant local identifier without a backend.
String newLocalId(String prefix) {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final salt = _random.nextInt(1 << 32).toRadixString(36);
  return '${prefix}_${time}_$salt';
}
