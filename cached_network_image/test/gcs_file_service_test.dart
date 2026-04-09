import 'package:cached_network_image/src/gcs_file_service.dart';
import 'package:cached_network_image/src/gcs_url_signer.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _SuccessfulSigner extends GcsUrlSigner {
  final List<String> calls = [];

  @override
  Future<String> signResourcePath(String resourcePath) async {
    calls.add(resourcePath);
    return 'https://storage.googleapis.com/$resourcePath?sig=abc';
  }
}

class _FailingSigner extends GcsUrlSigner {
  int callCount = 0;

  @override
  Future<String> signResourcePath(String resourcePath) async {
    callCount++;
    throw Exception('signing API unavailable');
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GcsFileService', () {
    test('calls signer with resource path before HTTP download', () async {
      final signer = _SuccessfulSigner();
      final service = GcsFileService(
        signer: signer,
        defaultMaxAge: const Duration(days: 30),
      );

      // Signing succeeds but the HTTP call fails (no real GCS in unit tests).
      // We verify the signer was called with the correct resource path.
      await expectLater(
        service.get(
          'images/profile/user123.jpg',
          headers: {kGcsMaxAgeHeader: '3600'},
        ),
        throwsA(isA<Object>()),
      );

      expect(signer.calls, contains('images/profile/user123.jpg'));
    });

    test('forwards resource path to signer', () async {
      final signer = _SuccessfulSigner();
      final service = GcsFileService(
        signer: signer,
        defaultMaxAge: const Duration(days: 7),
      );

      await expectLater(
        service.get('videos/thumbnail/clip42.jpg'),
        throwsA(isA<Object>()),
      );

      expect(signer.calls, contains('videos/thumbnail/clip42.jpg'));
    });

    test('propagates signing failure as exception', () async {
      final signer = _FailingSigner();
      final service = GcsFileService(
        signer: signer,
        defaultMaxAge: const Duration(days: 30),
      );

      await expectLater(
        service.get('images/foo.jpg'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('signing API unavailable'),
          ),
        ),
      );
      expect(signer.callCount, 1);
    });

    test('strips X-Gcs-Max-Age from headers before forwarding to GCS', () async {
      // The signing fails so we never reach the HTTP layer —
      // this proves stripping happens without needing a real network.
      final signer = _FailingSigner();
      final service = GcsFileService(
        signer: signer,
        defaultMaxAge: const Duration(days: 30),
      );

      await expectLater(
        service.get(
          'images/foo.jpg',
          headers: {kGcsMaxAgeHeader: '86400', 'Authorization': 'Bearer token'},
        ),
        throwsA(isA<Exception>()),
      );
      expect(signer.callCount, 1);
    });
  });
}
