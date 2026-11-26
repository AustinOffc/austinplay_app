import 'package:auzify/core/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('absUrl menggabungkan base URL', () {
    expect(AppConfig.absUrl(null), isNull);
    expect(AppConfig.absUrl('https://x.test/a.png'), 'https://x.test/a.png');
    expect(AppConfig.absUrl('/api/auth/avatar/1?v=2'), startsWith('http'));
  });
}
