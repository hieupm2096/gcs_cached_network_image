# gcs_cached_network_image — Integration Guide

## Why this package exists

Standard image caching packages use the full URL as the cache key. GCS signed URLs expire after a short window, so the same image has a different URL each time it is fetched — defeating the cache entirely.

This package caches by the stable **resource path** (e.g. `generated/user123/abc.jpg`) instead. When a cached image goes stale, your app's signing backend is called once to get a fresh URL, then the image is re-downloaded and stored again under the same key.

---

## 1. Add the dependency

```yaml
# pubspec.yaml
dependencies:
  gcs_cached_network_image:
    path: ../gcs_cached_network_image/cached_network_image   # local path
    # or, from a git remote:
    # git:
    #   url: https://github.com/your-org/gcs_cached_network_image.git
    #   ref: main
```

---

## 2. Implement `GcsUrlSigner`

Create a class that calls your backend to re-sign a GCS resource path into a fresh signed URL. The method is called only when a cached image has expired.

```dart
// lib/services/image_caching/my_image_signer.dart
import 'package:gcs_cached_network_image/gcs_cached_network_image.dart';

class MyImageSigner implements GcsUrlSigner {
  const MyImageSigner();

  @override
  Future<String> signResourcePath(String resourcePath) async {
    // Call your backend. The exact API will vary per project.
    final response = await myApiClient.generateSignedUrl(resourcePath);
    return response.signedUrl;
  }
}
```

### Example: `RabbitImageSigner` (wedding_ai app)

The wedding_ai app uses `rabbit_client` to call the `/fs/signed-urls` endpoint:

```dart
// lib/data/services/image_caching_service/rabbit_image_signer.dart
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:gcs_cached_network_image/gcs_cached_network_image.dart';

import '../rabbit_client/api_service.dart';

class RabbitImageSigner implements GcsUrlSigner {
  const RabbitImageSigner();

  @override
  Future<String> signResourcePath(String resourcePath) async {
    if (kDebugMode) log('[GcsCache] SIGNING: $resourcePath', name: 'gcs_cached_network_image');
    try {
      final url = await ApiService.instance.files.generateSignedUrl(resourcePath);
      if (kDebugMode) log('[GcsCache] SIGNED:  $resourcePath', name: 'gcs_cached_network_image');
      return url;
    } catch (e) {
      if (kDebugMode) log('[GcsCache] SIGN ERROR: $resourcePath — $e', name: 'gcs_cached_network_image');
      rethrow;
    }
  }
}
```

`ApiService.instance.files.generateSignedUrl` wraps the generated `FilesClient.generateSignedUrlsSignedUrlsPost` method:

```dart
// In FilesService
Future<String> generateSignedUrl(String resourcePath) {
  return wrap_with_feedback_handling(() async {
    final response = await client.api.fs.files.generateSignedUrlsSignedUrlsPost(
      body: SignedUrlsRequest(gcsPaths: [resourcePath]),
    );
    if (response.status == .fail || response.data == null || response.data!.signedUrls.isEmpty) {
      throw UnexpectedErrorException(
        message: '${response.message}: [${response.errorCode}] - ${response.description}',
      );
    }
    return response.data!.signedUrls.first;
  });
}
```

---

## 3. Configure at app startup

Call `GcsSignerRegistry.configure` once before any `GcsCachedNetworkImage` widget is built — typically as the first line of `main()`:

```dart
void main() async {
  GcsSignerRegistry.configure(
    signer: const MyImageSigner(),   // your GcsUrlSigner implementation
    defaultMaxAge: const Duration(days: 30),
  );
  await initializeApp();
  runApp(const MyApp());
}
```

| Parameter | Default | Description |
|---|---|---|
| `signer` | required | Your `GcsUrlSigner` implementation |
| `defaultMaxAge` | `Duration(days: 30)` | How long a cached image is considered fresh |
| `retryAttempts` | `3` | How many times to retry signing on failure |
| `retryBaseDelay` | `Duration(seconds: 2)` | Base delay for exponential-backoff retries |

---

## 4. Use the widget

```dart
GcsCachedNetworkImage(
  resourcePath: 'generated/user123/abc.jpg',   // stable GCS object path
  placeholder: (context, path) => const CircularProgressIndicator(),
  errorWidget: (context, path, error) => const Icon(Icons.broken_image),
  fit: BoxFit.cover,
  width: 200,
  height: 200,
)
```

### Passing signed URLs (backwards compatibility)

A signed URL is also accepted. The bucket and query string are stripped automatically so the cache key is always the stable resource path:

```dart
GcsCachedNetworkImage(
  // signed URL → cache key becomes 'generated/user123/abc.jpg'
  resourcePath: 'https://storage.googleapis.com/my-bucket/generated/user123/abc.jpg?X-Goog-...',
  ...
)
```

> **TODO:** Remove signed URL support once all callers have been migrated to pass bare resource paths.

### Extracting the resource path from a model URL

Use the exported `extractGcsResourcePath` helper to build the path in your model layer, keeping widget call sites clean:

```dart
import 'package:gcs_cached_network_image/gcs_cached_network_image.dart';

extension ImageModelExt on ImageModel {
  String? get thumbnailPath => extractGcsResourcePath(thumbnailUrl);
  String? get generatedImagePath => extractGcsResourcePath(generatedImageUrl);
}
```

Then in your widget:

```dart
GcsCachedNetworkImage(resourcePath: item.thumbnailPath ?? '')
```

---

## 5. Cache eviction

Evict a single image from both disk and memory when it is deleted server-side:

```dart
await GcsCachedNetworkImage.evictFromCache('generated/user123/abc.jpg');

// A signed URL is also accepted — resolves to the same cache key:
await GcsCachedNetworkImage.evictFromCache(imageModel.generatedImageUrl ?? '');
```

---

## 6. Downloading or sharing the cached file

`GcsCacheManager` exposes the underlying `flutter_cache_manager` API. Use `getSingleFile` to get a `File` for sharing or saving to the gallery:

```dart
import 'package:gcs_cached_network_image/gcs_cached_network_image.dart';

final file = await GcsCacheManager.instance.getSingleFile('generated/user123/abc.jpg');
final bytes = await file.readAsBytes();
await Gal.putImageBytes(bytes);                    // save to gallery
final xFile = XFile.fromData(bytes, mimeType: 'image/png');
await SharePlus.instance.share(ShareParams(files: [xFile]));  // share
```

---

## 7. Verifying the cache in debug builds

All logs use `dart:developer`'s `log` with the name `gcs_cached_network_image` and are gated behind `kDebugMode`. Filter your console to `gcs_cached_network_image` to see only cache events.

| Log message | Meaning |
|---|---|
| `[GcsCache] DOWNLOAD: <path>` | Cache miss — image will be signed and fetched |
| `[GcsCache] SIGNING: <path>` | Signer is being called |
| `[GcsCache] SIGNED:  <path>` | Signing succeeded |
| `[GcsCache] SIGN ERROR: <path> — <err>` | Signing failed |
| `[GcsCache] STALE FALLBACK: <path>` | Signing failed but a stale copy was served |
| `[GcsCache] ERROR: no cache for <path>` | Signing failed with no cached copy — error widget shown |

**Expected behaviour on first load:** `DOWNLOAD` → `SIGNING` → `SIGNED` for each image.  
**Expected behaviour on second load:** no logs at all — the cached copy is served directly.

To force expiry quickly during development, temporarily lower `defaultMaxAge`:

```dart
GcsSignerRegistry.configure(
  signer: const MyImageSigner(),
  defaultMaxAge: const Duration(seconds: 5),  // expires fast for testing
);
```

Check programmatically whether a specific image is cached:

```dart
final info = await GcsCacheManager.instance.getFileFromCache('generated/user123/abc.jpg');
debugPrint(info == null
  ? 'NOT cached'
  : 'Cached at ${info.file.path}, valid until ${info.validTill}');
```
