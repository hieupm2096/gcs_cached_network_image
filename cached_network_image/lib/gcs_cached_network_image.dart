/// GCS-aware fork of cached_network_image.
///
/// Caches images by their stable GCS resource path rather than by the
/// temporary signed URL.
///
/// ## Setup
///
/// ```dart
/// // In main() or app initialisation:
/// GcsSignerRegistry.configure(
///   signer: MyApiSigner(),
///   defaultMaxAge: Duration(days: 30),
/// );
/// ```
///
/// ## Usage
///
/// ```dart
/// GcsCachedNetworkImage(
///   resourcePath: 'images/profile/user123.jpg',
///   placeholder: (context, path) => CircularProgressIndicator(),
///   errorWidget: (context, path, error) => Icon(Icons.error),
/// )
/// ```
library gcs_cached_network_image;

export 'cached_network_image.dart';

export 'src/gcs_cache_manager.dart';
export 'src/gcs_cached_image_widget.dart';
export 'src/gcs_cached_network_image_provider.dart';
export 'src/gcs_signer_registry.dart';
export 'src/gcs_url_signer.dart';
