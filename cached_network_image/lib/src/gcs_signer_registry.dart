import 'gcs_url_signer.dart';

/// Global registry for GCS image caching configuration.
///
/// Call [GcsSignerRegistry.configure] once at app startup before any
/// [GcsCachedNetworkImage] widget is built.
///
/// ```dart
/// GcsSignerRegistry.configure(
///   signer: MyApiSigner(),
///   defaultMaxAge: Duration(days: 30),
/// );
/// ```
class GcsSignerRegistry {
  GcsSignerRegistry._({
    required this.signer,
    required this.defaultMaxAge,
    required this.retryAttempts,
    required this.retryBaseDelay,
  });

  /// The default signer used for all images unless overridden per-widget.
  final GcsUrlSigner signer;

  /// How long cached images are considered fresh. Defaults to 30 days.
  final Duration defaultMaxAge;

  /// Number of retry attempts when the signing API fails. Defaults to 3.
  final int retryAttempts;

  /// Base delay for exponential backoff retries. Defaults to 2 seconds.
  final Duration retryBaseDelay;

  static GcsSignerRegistry? _instance;

  /// The configured registry instance.
  ///
  /// Throws [StateError] if [configure] has not been called.
  static GcsSignerRegistry get instance {
    if (_instance == null) {
      throw StateError(
        'GcsSignerRegistry has not been configured. '
        'Call GcsSignerRegistry.configure() before using GcsCachedNetworkImage.',
      );
    }
    return _instance!;
  }

  /// Configure the registry. Must be called before any [GcsCachedNetworkImage]
  /// widget is built, typically in [main] or app initialisation.
  static void configure({
    required GcsUrlSigner signer,
    Duration defaultMaxAge = const Duration(days: 30),
    int retryAttempts = 3,
    Duration retryBaseDelay = const Duration(seconds: 2),
  }) {
    _instance = GcsSignerRegistry._(
      signer: signer,
      defaultMaxAge: defaultMaxAge,
      retryAttempts: retryAttempts,
      retryBaseDelay: retryBaseDelay,
    );
  }

  /// Resets the registry to unconfigured state. Intended for use in tests only.
  static void reset() {
    _instance = null;
  }
}
