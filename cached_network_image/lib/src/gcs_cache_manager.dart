import 'dart:async';
import 'dart:developer';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'gcs_file_service.dart';
import 'gcs_signer_registry.dart';
import 'gcs_url_signer.dart';

/// Cache manager for GCS images.
///
/// Images are stored on disk keyed by their resource path. On cache expiry,
/// [GcsFileService] is called to obtain a fresh signed URL and re-download.
///
/// Use [GcsCacheManager.instance] for the default signer, or
/// [GcsCacheManager.forSigner] to get a manager bound to a specific signer.
class GcsCacheManager extends CacheManager with ImageCacheManager {
  static const _defaultCacheKey = 'gcsImageCache';

  static GcsCacheManager? _instance;

  /// The default singleton cache manager, using the signer from
  /// [GcsSignerRegistry].
  static GcsCacheManager get instance {
    _instance ??= GcsCacheManager._create(
      _defaultCacheKey,
      GcsSignerRegistry.instance.signer,
    );
    return _instance!;
  }

  static final Map<GcsUrlSigner, GcsCacheManager> _signerInstances = {};

  /// Returns a cache manager bound to [signer], creating one if needed.
  ///
  /// Each unique [signer] instance gets its own on-disk store so that
  /// different authorization domains don't share cached entries.
  static GcsCacheManager forSigner(GcsUrlSigner signer) {
    return _signerInstances.putIfAbsent(
      signer,
      () => GcsCacheManager._create(
        '${_defaultCacheKey}_${signer.hashCode}',
        signer,
      ),
    );
  }

  /// Resets all singleton instances. Intended for use in tests only.
  static void resetInstances() {
    _instance = null;
    _signerInstances.clear();
  }

  GcsCacheManager._create(String cacheKey, GcsUrlSigner signer)
      : super(
          Config(
            cacheKey,
            stalePeriod: GcsSignerRegistry.instance.defaultMaxAge,
            fileService: GcsFileService(
              signer: signer,
              defaultMaxAge: GcsSignerRegistry.instance.defaultMaxAge,
            ),
          ),
        );

  // ── Overrides with stale-while-revalidate ──────────────────────────────

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    return _withStaleFallback(
      super.getFileStream(
        url,
        key: key,
        headers: headers,
        withProgress: withProgress,
      ),
      cacheKey: key ?? url,
      url: url,
      key: key,
      headers: headers,
    );
  }

  @override
  Stream<FileResponse> getImageFile(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
    int? maxHeight,
    int? maxWidth,
  }) {
    return _withStaleFallback(
      super.getImageFile(
        url,
        key: key,
        headers: headers,
        withProgress: withProgress,
        maxHeight: maxHeight,
        maxWidth: maxWidth,
      ),
      cacheKey: key ?? url,
      url: url,
      key: key,
      headers: headers,
    );
  }

  /// Wraps [source] so that on error, a stale cached entry is served instead
  /// and a background retry is scheduled.
  Stream<FileResponse> _withStaleFallback(
    Stream<FileResponse> source, {
    required String cacheKey,
    required String url,
    String? key,
    Map<String, String>? headers,
  }) {
    final controller = StreamController<FileResponse>();

    source.listen(
      controller.add,
      onError: (Object error, StackTrace stackTrace) async {
        final stale =
            await getFileFromCache(cacheKey, ignoreMemCache: true);
        if (stale != null) {
          if (kDebugMode) log('[GcsCache] STALE FALLBACK: serving cached copy of $cacheKey (error: $error)', name: 'gcs_cached_network_image');
          controller.add(stale);
          _scheduleRetry(url, key: key, headers: headers);
        } else {
          if (kDebugMode) log('[GcsCache] ERROR: no cache for $cacheKey, propagating error', name: 'gcs_cached_network_image');
          controller.addError(error, stackTrace);
        }
        unawaited(controller.close());
      },
      onDone: () => unawaited(controller.close()),
      cancelOnError: true,
    );

    return controller.stream;
  }

  void _scheduleRetry(
    String url, {
    String? key,
    Map<String, String>? headers,
    int attempt = 0,
  }) {
    final registry = GcsSignerRegistry.instance;
    if (attempt >= registry.retryAttempts) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: Exception(
            'GcsCacheManager: failed to refresh "$url" '
            'after ${registry.retryAttempts} retries.',
          ),
          library: 'gcs_cached_network_image',
          context: ErrorDescription('refreshing expired GCS cached image'),
        ),
      );
      return;
    }

    final delay =
        registry.retryBaseDelay * pow(2, attempt).toInt();
    Future<void>.delayed(delay, () async {
      try {
        await downloadFile(url, key: key ?? url, authHeaders: headers);
      } catch (_) {
        _scheduleRetry(url, key: key, headers: headers, attempt: attempt + 1);
      }
    });
  }
}
