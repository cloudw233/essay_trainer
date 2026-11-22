import 'package:flutter/services.dart';

/// Sends report text to the Android system share sheet.
///
/// The channel is implemented in [MainActivity]. Tests and unsupported hosts
/// receive `false`, allowing the report page to copy to the clipboard instead.
class SystemShare {
  const SystemShare._();

  static const MethodChannel channel = MethodChannel('essay_trainer/share');

  static Future<bool> shareText({required String text, String? subject}) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return false;
    final trimmedSubject = subject?.trim();
    try {
      final result = await channel.invokeMethod<bool>('shareText', {
        'text': trimmedText,
        if (trimmedSubject != null && trimmedSubject.isNotEmpty)
          'subject': trimmedSubject,
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
