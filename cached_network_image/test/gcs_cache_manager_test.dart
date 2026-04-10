import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gcs_cached_network_image/gcs_cached_network_image.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeSigner extends GcsUrlSigner {
  @override
  Future<String> signResourcePath(String resourcePath) async =>
      'https://storage.googleapis.com/$resourcePath?sig=fake';
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Use in-process SQLite so flutter_cache_manager can open its store
    // without a native plugin.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Mock path_provider so flutter_cache_manager can resolve temp/support dirs.
    final tempDir = Directory.systemTemp.createTempSync('gcs_cache_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
  });

  setUp(() {
    GcsSignerRegistry.configure(
      signer: _FakeSigner(),
      defaultMaxAge: const Duration(days: 30),
      retryAttempts: 3,
      retryBaseDelay: const Duration(milliseconds: 1),
    );
  });

  tearDown(() {
    GcsSignerRegistry.reset();
    GcsCacheManager.resetInstances();
  });

  group('GcsCacheManager.instance', () {
    test('returns the same instance on repeated access', () {
      final a = GcsCacheManager.instance;
      final b = GcsCacheManager.instance;
      expect(a, same(b));
    });

    test('throws StateError if registry not configured', () {
      GcsSignerRegistry.reset();
      GcsCacheManager.resetInstances();
      expect(() => GcsCacheManager.instance, throwsStateError);
    });
  });

  group('GcsCacheManager.forSigner', () {
    test('returns different managers for different signer instances', () {
      final s1 = _FakeSigner();
      final s2 = _FakeSigner();
      final m1 = GcsCacheManager.forSigner(s1);
      final m2 = GcsCacheManager.forSigner(s2);
      expect(m1, isNot(same(m2)));
    });

    test('returns same manager for same signer instance', () {
      final signer = _FakeSigner();
      final m1 = GcsCacheManager.forSigner(signer);
      final m2 = GcsCacheManager.forSigner(signer);
      expect(m1, same(m2));
    });
  });
}
