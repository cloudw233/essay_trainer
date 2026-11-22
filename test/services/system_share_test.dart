import 'package:essay_trainer/services/system_share.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemShare.channel, null);
  });

  test('sends text and subject through the native share channel', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(SystemShare.channel, (call) async {
      received = call;
      return true;
    });

    final shared = await SystemShare.shareText(
      text: 'report body',
      subject: 'A Turning Point',
    );

    expect(shared, isTrue);
    expect(received?.method, 'shareText');
    expect(received?.arguments, {
      'text': 'report body',
      'subject': 'A Turning Point',
    });
  });

  test('returns false when the native channel is unavailable', () async {
    messenger.setMockMethodCallHandler(SystemShare.channel, null);
    expect(await SystemShare.shareText(text: 'report body'), isFalse);
  });
}
