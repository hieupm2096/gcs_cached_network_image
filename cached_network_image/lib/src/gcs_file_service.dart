import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'gcs_url_signer.dart';

/// Header key used to pass a per-request max-age to [GcsFileService].
/// This header is stripped before forwarding the request to GCS.
const kGcsMaxAgeHeader = 'X-Gcs-Max-Age';

/// [FileService] implementation that signs GCS resource paths before
/// downloading.
///
/// The [url] parameter received by [get] is treated as a GCS resource path
/// (not an HTTP URL). [GcsFileService] calls [signer] to obtain a temporary
/// signed URL, then downloads from that URL.
class GcsFileService implements FileService {
  GcsFileService({required this.signer, required this.defaultMaxAge});

  /// The signer used to convert resource paths into signed URLs.
  final GcsUrlSigner signer;

  /// Default cache TTL, used when no [kGcsMaxAgeHeader] is present.
  final Duration defaultMaxAge;

  @override
  int concurrentFetches = 10;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    // url is the GCS resource path, e.g. "images/profile/user123.jpg"
    var maxAge = defaultMaxAge;
    final cleanHeaders = <String, String>{};

    headers?.forEach((key, value) {
      if (key == kGcsMaxAgeHeader) {
        final seconds = int.tryParse(value);
        if (seconds != null) maxAge = Duration(seconds: seconds);
      } else {
        cleanHeaders[key] = value;
      }
    });

    if (kDebugMode) log('[GcsCache] DOWNLOAD: $url', name: 'gcs_cached_network_image');

    final signedUrl = await signer.signResourcePath(url);

    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(signedUrl));
    cleanHeaders.forEach((k, v) => request.headers.add(k, v));
    final response = await request.close();

    if (response.statusCode != 200) {
      throw HttpExceptionWithStatus(
        response.statusCode,
        'Invalid statusCode: ${response.statusCode}',
        uri: Uri.parse(signedUrl),
      );
    }

    return _GcsFileServiceResponse(response, maxAge: maxAge);
  }
}

class _GcsFileServiceResponse implements FileServiceResponse {
  _GcsFileServiceResponse(this._response, {required this.maxAge});

  final HttpClientResponse _response;
  final Duration maxAge;

  @override
  Stream<List<int>> get content => _response;

  @override
  int? get contentLength =>
      _response.contentLength == -1 ? null : _response.contentLength;

  @override
  int get statusCode => _response.statusCode;

  @override
  DateTime get validTill => DateTime.now().add(maxAge);

  @override
  String? get eTag => _response.headers.value('etag');

  @override
  String get fileExtension {
    final sub = _response.headers.contentType?.subType ?? '';
    switch (sub) {
      case 'jpeg':
      case 'jpg':
        return '.jpg';
      case 'png':
        return '.png';
      case 'gif':
        return '.gif';
      case 'webp':
        return '.webp';
      case 'bmp':
        return '.bmp';
      default:
        return '.file';
    }
  }
}
