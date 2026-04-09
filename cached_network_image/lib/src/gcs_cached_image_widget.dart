import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'gcs_cache_manager.dart';
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

  /// The stable GCS resource path, e.g. `images/profile/user123.jpg`.
  /// Used as the cache key — never the signed URL.
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

  /// Evicts [resourcePath] from both disk and memory caches.
  static Future<bool> evictFromCache(
    String resourcePath, {
    double scale = 1.0,
    GcsUrlSigner? signer,
  }) {
    final manager =
        signer != null ? GcsCacheManager.forSigner(signer) : GcsCacheManager.instance;
    return CachedNetworkImage.evictFromCache(
      resourcePath,
      cacheKey: resourcePath,
      cacheManager: manager,
      scale: scale,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: resourcePath,
      cacheKey: resourcePath,
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
