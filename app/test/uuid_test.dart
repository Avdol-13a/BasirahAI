import 'package:flutter_test/flutter_test.dart';
import 'package:basirah_app/utils/uuid.dart';

void main() {
  test('generateUuidV4 produces a well-formed, unique v4 UUID', () {
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    final seen = <String>{};
    for (var i = 0; i < 200; i++) {
      final id = generateUuidV4();
      expect(id, matches(uuidPattern));
      expect(seen.add(id), isTrue, reason: 'generated a duplicate UUID: $id');
    }
  });
}
