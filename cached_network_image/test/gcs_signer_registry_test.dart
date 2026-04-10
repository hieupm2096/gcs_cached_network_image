import 'package:flutter_test/flutter_test.dart';
import 'package:gcs_cached_network_image/gcs_cached_network_image.dart';

class _FakeSigner extends GcsUrlSigner {
  @override
  Future<String> signResourcePath(String resourcePath) async =>
      'https://storage.googleapis.com/$resourcePath?X-Goog-Signature=fake';
}

class _OtherSigner extends GcsUrlSigner {
  @override
  Future<String> signResourcePath(String resourcePath) async =>
      'https://other.example.com/$resourcePath?sig=other';
}

void main() {
  tearDown(GcsSignerRegistry.reset);

  test('accessing instance before configure throws StateError', () {
    expect(() => GcsSignerRegistry.instance, throwsStateError);
  });

  test('configure sets signer and defaults', () {
    final signer = _FakeSigner();
    GcsSignerRegistry.configure(signer: signer);

    final registry = GcsSignerRegistry.instance;
    expect(registry.signer, same(signer));
    expect(registry.defaultMaxAge, const Duration(days: 30));
    expect(registry.retryAttempts, 3);
    expect(registry.retryBaseDelay, const Duration(seconds: 2));
  });

  test('configure accepts custom values', () {
    GcsSignerRegistry.configure(
      signer: _FakeSigner(),
      defaultMaxAge: const Duration(days: 7),
      retryAttempts: 5,
      retryBaseDelay: const Duration(seconds: 4),
    );

    final registry = GcsSignerRegistry.instance;
    expect(registry.defaultMaxAge, const Duration(days: 7));
    expect(registry.retryAttempts, 5);
    expect(registry.retryBaseDelay, const Duration(seconds: 4));
  });

  test('configure can be called again to replace configuration', () {
    GcsSignerRegistry.configure(signer: _FakeSigner());
    final second = _OtherSigner();
    GcsSignerRegistry.configure(signer: second);

    expect(GcsSignerRegistry.instance.signer, same(second));
  });

  test('reset returns registry to unconfigured state', () {
    GcsSignerRegistry.configure(signer: _FakeSigner());
    GcsSignerRegistry.reset();

    expect(() => GcsSignerRegistry.instance, throwsStateError);
  });
}
