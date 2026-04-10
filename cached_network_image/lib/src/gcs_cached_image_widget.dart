import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'gcs_cache_manager.dart';
import 'gcs_resource_path.dart';
import 'gcs_url_signer.dart';

/// Drop-in replacement for [CachedNetworkImage] that caches GCS images by
/// resource path rather than signed URL.
///
/// Configure once at startup:
/// ```dart
/// GcsSignerRegistry.configure(signer: MyApiSigner());
/// ```
///
/// Then use in your widgets:
/// ```dart
/// GcsCachedNetworkImage(
///   resourcePath: 'images/profile/user123.jpg',
///   placeholder: (context, path) => CircularProgressIndicator(),
///   errorWidget: (context, path, error) => Icon(Icons.error),
/// )
/// ```
class GcsCachedNetworkImage extends StatelessWidget {
  const GcsCachedNetworkImage({
    super.key,
    required this.resourcePath,
    this.maxAge,
    this.signer,
    this.httpHeaders,
    this.imageBuilder,
    this.placeholder,
    this.progressIndicatorBuilder,
    this.errorWidget,
    this.fadeOutDuration = const Duration(milliseconds: 1000),
    this.fadeOutCurve = Curves.easeOut,
    this.fadeInDuration = const Duration(milliseconds: 500),
    this.fadeInCurve = Curves.easeIn,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.matchTextDirection = false,
    this.useOldImageOnUrlChange = false,
    this.color,
    this.filterQuality = FilterQuality.low,
    this.colorBlendMode,
    this.placeholderFadeInDuration,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
    this.errorListener,
    this.scale = 1.0,
  });

  /// The GCS resource path or a signed GCS URL for this image.
  ///
  /// Prefer passing a stable resource path (e.g. `images/profile/user123.jpg`)
  /// so the cache key never changes across URL re-signings.
  ///
  /// A signed URL (`https://storage.googleapis.com/{bucket}/{path}?X-Goog-...`)
  /// is also accepted for backwards compatibility: the bucket and query string
  /// are stripped automatically and the resulting path is used as the cache key.
  ///
  // TODO: remove signed URL support once all callers pass bare resource paths.
  final String resourcePath;

  /// Override the cache TTL for this image. If null, uses the global default
  /// from [GcsSignerRegistry].
  final Duration? maxAge;

  /// Override the signer for this image. If null, uses the global signer from
  /// [GcsSignerRegistry].
  final GcsUrlSigner? signer;

  final Map<String, String>? httpHeaders;
  final ImageWidgetBuilder? imageBuilder;
  final PlaceholderWidgetBuilder? placeholder;
  final ProgressIndicatorBuilder? progressIndicatorBuilder;
  final LoadingErrorWidgetBuilder? errorWidget;
  final Duration fadeOutDuration;
  final Curve fadeOutCurve;
  final Duration fadeInDuration;
  final Curve fadeInCurve;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Alignment alignment;
  final ImageRepeat repeat;
  final bool matchTextDirection;
  final bool useOldImageOnUrlChange;
  final Color? color;
  final FilterQuality filterQuality;
  final BlendMode? colorBlendMode;
  final Duration? placeholderFadeInDuration;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;
  final ValueChanged<Object>? errorListener;
  final double scale;

  /// Returns the stable cache key for this widget's [resourcePath].
  ///
  /// If [resourcePath] is a signed GCS URL the bucket and query string are
  /// stripped; otherwise the value is returned unchanged.
  String get _resolvedPath => extractGcsResourcePath(resourcePath) ?? resourcePath;

  /// Evicts [resourcePath] from both disk and memory caches.
  ///
  /// Accepts either a bare resource path or a signed GCS URL — both resolve
  /// to the same cache key.
  static Future<bool> evictFromCache(
    String resourcePath, {
    double scale = 1.0,
    GcsUrlSigner? signer,
  }) {
    final resolved = extractGcsResourcePath(resourcePath) ?? resourcePath;
    final manager =
        signer != null ? GcsCacheManager.forSigner(signer) : GcsCacheManager.instance;
    return CachedNetworkImage.evictFromCache(
      resolved,
      cacheKey: resolved,
      cacheManager: manager,
      scale: scale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedPath;
    return CachedNetworkImage(
      imageUrl: resolved,
      cacheKey: resolved,
      cacheManager: signer != null
          ? GcsCacheManager.forSigner(signer!)
          : GcsCacheManager.instance,
      httpHeaders: httpHeaders,
      imageBuilder: imageBuilder,
      placeholder: placeholder,
      progressIndicatorBuilder: progressIndicatorBuilder,
      errorWidget: errorWidget,
      fadeOutDuration: fadeOutDuration,
      fadeOutCurve: fadeOutCurve,
      fadeInDuration: fadeInDuration,
      fadeInCurve: fadeInCurve,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      matchTextDirection: matchTextDirection,
      useOldImageOnUrlChange: useOldImageOnUrlChange,
      color: color,
      filterQuality: filterQuality,
      colorBlendMode: colorBlendMode,
      placeholderFadeInDuration: placeholderFadeInDuration,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxWidthDiskCache: maxWidthDiskCache,
      maxHeightDiskCache: maxHeightDiskCache,
      errorListener: errorListener,
      scale: scale,
    );
  }
}
