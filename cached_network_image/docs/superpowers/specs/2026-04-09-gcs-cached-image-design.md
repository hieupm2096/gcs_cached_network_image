# GCS Cached Network Image — Design Spec

**Date:** 2026-04-09  
**Status:** Approved

---

## Problem

`cached_network_image` caches images by URL. Google Cloud Storage signed URLs are temporary — they expire and change on each generation, so using them as cache keys causes cache misses on every URL rotation. We need to cache by the stable GCS resource path instead, and re-fetch a fresh signed URL only when the cached image has expired.

---

## Approach

Custom `FileService` (Approach 1: Sign-on-demand). The resource path is used as both the download URL and the cache key passed to `flutter_cache_manager`. A custom `GcsFileService` intercepts every download request, calls the signing API with the resource path, and downloads from the resulting signed URL. The cache manager's TTL handles expiry — the signing API is never called on cache hits.

---

## Components

### `GcsUrlSigner` (abstract class)

Implemented by the caller. The package calls this when a download is needed.

```dart
abstract class GcsUrlSigner {
  Future<String> signResourcePath(String resourcePath);
}
```

### `GcsSignerRegistry` (global singleton)

Holds the default signer, TTL, and retry configuration. Configured once at app startup.

```dart
GcsSignerRegistry.configure(
  signer: MyApiSigner(),
  defaultMaxAge: Duration(days: 30),
  retryAttempts: 3,
  retryBaseDelay: Duration(seconds: 2),
);
```

Throws `StateError` if any component tries to use it before `configure()` is called.

### `GcsFileService` (implements `FileService`)

Receives a resource path from the cache manager, calls the signer, performs the HTTP download from the signed URL. Handles retry with exponential backoff on signing failure.

Note: `FileService` has no direct access to cache state. The stale-while-revalidate behaviour (serving an expired cached file while a re-download is in progress) is handled at the `GcsCacheManager` level by catching signing failures from the stream, falling back to the stale `FileInfo` if one exists, and scheduling background retries independently.

### `GcsCacheManager` (extends `BaseCacheManager`)

Wired with `GcsFileService`. App-wide singleton accessed via `GcsCacheManager.instance`. Owns the on-disk image store with TTL-based expiry.

### `GcsCachedNetworkImageProvider` (extends `CachedNetworkImageProvider`)

Thin subclass. Forces `cacheKey = resourcePath` and wires in `GcsCacheManager`. Accepts an optional per-instance `GcsUrlSigner` override.

### `GcsCachedNetworkImage` (widget)

Drop-in replacement for `CachedNetworkImage`. Accepts `resourcePath` instead of `imageUrl`. All other parameters (`placeholder`, `errorWidget`, `fit`, etc.) are identical to the upstream widget.

---

## Public API

### App startup

```dart
GcsSignerRegistry.configure(
  signer: MyApiSigner(),
  defaultMaxAge: Duration(days: 30),
  retryAttempts: 3,                    // optional, default 3
  retryBaseDelay: Duration(seconds: 2), // optional, default 2s
);
```

### Signer implementation (in the app)

```dart
class MyApiSigner extends GcsUrlSigner {
  @override
  Future<String> signResourcePath(String resourcePath) async {
    final response = await myApi.getSignedUrl(resourcePath);
    return response.signedUrl;
  }
}
```

### Widget usage

```dart
// Minimal — uses global signer and default TTL
GcsCachedNetworkImage(
  resourcePath: 'images/profile/user123.jpg',
  placeholder: (context, path) => CircularProgressIndicator(),
  errorWidget: (context, path, error) => Icon(Icons.error),
)

// Per-widget overrides
GcsCachedNetworkImage(
  resourcePath: 'videos/thumbnails/clip42.jpg',
  maxAge: Duration(days: 7),
  signer: myOtherBucketSigner,
)
```

### Cache management

```dart
await GcsCachedNetworkImage.evictFromCache('images/profile/user123.jpg');
await GcsCacheManager.instance.emptyCache();
```

---

## Data Flow

### Cache miss / first load

1. Widget builds → creates `GcsCachedNetworkImageProvider(resourcePath)`
2. Provider calls `GcsCacheManager.getImageFile(resourcePath, key: resourcePath)`
3. Cache manager: no valid entry → calls `GcsFileService.get(resourcePath)`
4. `GcsFileService`: calls `signer.signResourcePath(resourcePath)` → signed URL
5. `GcsFileService`: HTTP GET signed URL → image bytes
6. Cache manager: stores bytes on disk, sets `validTill = now + maxAge`
7. Image rendered

### Cache hit (within TTL)

Steps 1–2 same. Cache manager finds a valid entry → returns `FileInfo` immediately. `GcsFileService` never called. Signing API never called.

### Cache expired

Same as cache miss — `flutter_cache_manager` treats expired entries as misses.

### Signing API fails (stale entry exists)

1. `GcsFileService` signing call fails
2. Stale `FileInfo` served immediately → user sees no disruption
3. Background retry with exponential backoff: 2s → 4s → 8s (configurable)
4. On retry success: cache updated, widget refreshes
5. On all retries exhausted: stale image persists, error reported via `FlutterError.reportError`

### Signing API fails (no cache)

Error propagated through the stream → widget shows `errorWidget`. Background retries still run; on success the image stream updates and the widget rebuilds.

### GCS download fails (signed URL obtained but HTTP error)

Propagated through `flutter_cache_manager` stream → widget shows `errorWidget`. No special handling — standard upstream behaviour.

---

## Error Handling

| Scenario | Cache exists? | Behaviour |
|---|---|---|
| Signing API fails | No | Show `errorWidget`; retry in background |
| Signing API fails | Yes (stale) | Show stale image; retry in background |
| All retries exhausted | No | `errorWidget` persists; error logged |
| All retries exhausted | Yes (stale) | Stale image persists; error logged |
| GCS download fails | N/A | Show `errorWidget` (upstream behaviour) |

**Out of scope:** Malformed signed URLs and non-existent GCS resources are treated as download failures. Signing API authentication is the responsibility of the caller's `GcsUrlSigner` implementation.

---

## Testing

### Unit — `GcsFileService`

- Signs and downloads successfully → correct bytes returned
- Signer throws → retries with backoff → succeeds on attempt N
- Signer throws → all retries exhausted → error propagated
- Mock `GcsUrlSigner` + mock HTTP client

### Unit — `GcsSignerRegistry`

- `configure()` sets signer and defaults correctly
- Per-widget signer overrides global signer
- Per-widget `maxAge` overrides global default
- Using registry before `configure()` throws `StateError`

### Integration — `GcsCacheManager`

- Cache miss → `GcsFileService` called → file stored with correct TTL
- Cache hit within TTL → `GcsFileService` never called
- Cache expired → `GcsFileService` called again
- Fake `GcsFileService` that records calls

### Widget — `GcsCachedNetworkImage`

- Renders placeholder while loading
- Renders image on success
- Renders `errorWidget` when no cache and signing fails after all retries
- Renders stale image when cache expired and signing fails
- Per-widget `signer` and `maxAge` wired through correctly

### Inherited (not re-tested)

Fade animations, placeholder/error widget lifecycle, codec decoding, and stream completion are covered by upstream `cached_network_image` tests.
