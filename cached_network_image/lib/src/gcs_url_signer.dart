/// Abstract interface for signing GCS resource paths into temporary signed URLs.
///
/// Implement this class in your app to call your backend signing API.
abstract class GcsUrlSigner {
  /// Returns a signed URL for the given [resourcePath].
  ///
  /// The [resourcePath] is the stable GCS object path, e.g.
  /// `images/profile/user123.jpg`. The returned URL must be a fully-qualified
  /// HTTPS URL valid for at least long enough to complete the download.
  Future<String> signResourcePath(String resourcePath);
}
