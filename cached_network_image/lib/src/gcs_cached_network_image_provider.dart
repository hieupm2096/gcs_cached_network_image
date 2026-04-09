// ignore_for_file: use_super_parameters
import 'package:cached_network_image/src/image_provider/cached_network_image_provider.dart';

import 'gcs_cache_manager.dart';
import 'gcs_file_service.dart';
import 'gcs_url_signer.dart';

/// An [ImageProvider] that loads GCS images by resource path.
///
/// The [resourcePath] is used as both the download key and the cache key, so
/// images are cached independently of the signed URL rotation.
///
/// Use [GcsCachedNetworkImage] widget for most cases. Use this provider
/// directly when you need to supply it to [Image.new] or another widget that
/// accepts an [ImageProvider].
///
/// ```dart
/// Image(image: GcsCachedNetworkImageProvider('images/profile/user123.jpg'))
/// ```
class GcsCachedNetworkImageProvider extends CachedNetworkImageProvider {
  GcsCachedNetworkImageProvider(
    String resourcePath, {
    super.scale = 1.0,
    this.maxAge,
    this.signer,
    Map<String, String>? headers,
    super.errorListener,
    super.maxHeight,
    super.maxWidth,
  }) : super(
          resourcePath,
          cacheKey: resourcePath,
          cacheManager: signer != null
              ? GcsCacheManager.forSigner(signer)
              : GcsCacheManager.instance,
          headers: _buildHeaders(headers, maxAge),
        );

  /// Override the cache TTL for this image. If null, uses the global default
  /// from [GcsSignerRegistry].
  final Duration? maxAge;

  /// Override the signer for this image. If null, uses the global signer from
  /// [GcsSignerRegistry].
  final GcsUrlSigner? signer;

  static Map<String, String>? _buildHeaders(
    Map<String, String>? headers,
    Duration? maxAge,
  ) {
    if (maxAge == null) return headers;
    final result = <String, String>{...?headers};
    result[kGcsMaxAgeHeader] = maxAge.inSeconds.toString();
    return result;
  }
}
