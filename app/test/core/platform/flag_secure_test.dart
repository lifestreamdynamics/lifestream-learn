import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/core/platform/flag_secure.dart';

void main() {
  const channelName = 'com.lifestream.learn/flag_secure';

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() {
    FlagSecure.testChannel = null;
  });

  testWidgets('FlagSecure.enable invokes the "enable" method', (tester) async {
    final calls = <String>[];
    final channel = MethodChannel(channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    FlagSecure.testChannel = channel;

    await FlagSecure.enable();
    expect(calls, ['enable']);
  });

  testWidgets('FlagSecure.disable invokes the "disable" method',
      (tester) async {
    final calls = <String>[];
    final channel = MethodChannel(channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    FlagSecure.testChannel = channel;

    await FlagSecure.disable();
    expect(calls, ['disable']);
  });

  testWidgets('paired enable/disable dispatches both', (tester) async {
    final calls = <String>[];
    final channel = MethodChannel(channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    FlagSecure.testChannel = channel;

    await FlagSecure.enable();
    await FlagSecure.disable();
    expect(calls, ['enable', 'disable']);
  });
}
