/// Extracts the stable GCS resource path from a signed URL.
///
/// Signed GCS URLs have the form:
/// `https://storage.googleapis.com/{bucket}/{object_path}?X-Goog-...`
///
/// This function strips the bucket segment and query string, returning only
/// `{object_path}`, e.g. `generated/user123/abc.jpg`.
///
/// If [input] is already a bare resource path (does not start with `https://`),
/// it is returned unchanged. Returns `null` for null or empty input, and for
/// URLs that contain no object path beyond the bucket.
///
/// ```dart
/// extractGcsResourcePath(
///   'https://storage.googleapis.com/my-bucket/generated/user/img.jpg?X-Goog-...'
/// ); // → 'generated/user/img.jpg'
///
/// extractGcsResourcePath('generated/user/img.jpg'); // → 'generated/user/img.jpg'
/// extractGcsResourcePath(null);                     // → null
/// ```
String? extractGcsResourcePath(String? input) {
  if (input == null || input.isEmpty) return null;
  if (!input.startsWith('https://')) return input;
  final uri = Uri.tryParse(input);
  if (uri == null) return input;
  final segments = uri.pathSegments;
  if (segments.length <= 1) return null;
  return segments.skip(1).join('/');
}
