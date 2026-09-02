import 'dart:math';

/// Generates a random RFC 4122 version-4 UUID without adding a package
/// dependency for it. Used to give each screening a client-generated,
/// stable id up front, so saving it to Supabase can be retried as an
/// idempotent upsert instead of risking a duplicate row per retry.
String generateUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3F) | 0x80; // RFC 4122 variant

  String hex(int start, int end) =>
      bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
