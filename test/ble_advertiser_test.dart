import 'package:flutter_test/flutter_test.dart';
import 'package:u_chat/core/bluetooth/ble_advertiser.dart';

void main() {
  test('extracts the Android error code from the plugin exception text', () {
    const raw = 'PlatformException(IllegalStateException, java.lang.IllegalStateException: '
        'Start advertising failed with error code: 3, Cause: null, Stacktrace: ...)';
    expect(BleAdvertiser.errorCode(raw), 3);
    expect(BleAdvertiser.errorCode('something else'), isNull);
  });

  test('user-facing messages never contain stack traces', () {
    for (final code in [1, 2, 3, 4, 5, 99]) {
      final message = BleAdvertiser.describeError('failed with error code: $code');
      expect(message, isNot(contains('Exception')));
      expect(message.length, lessThan(200));
    }
  });
}
