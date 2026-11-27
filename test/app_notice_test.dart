import 'package:flutter_test/flutter_test.dart';
import 'package:auzify/widgets/app_notice.dart';

void main() {
  test('versionOlder membandingkan versi semantik', () {
    expect(versionOlder('1.0.0', '1.0.1'), isTrue);
    expect(versionOlder('1.2.0', '1.10.0'), isTrue);
    expect(versionOlder('2.0.0', '1.9.9'), isFalse);
    expect(versionOlder('1.0.0', '1.0.0'), isFalse);
    expect(versionOlder('1.0.0+5', '1.0.0'), isFalse);
  });
}
