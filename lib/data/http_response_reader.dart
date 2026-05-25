import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class HttpBodyTooLargeException implements Exception {
  final int maxBytes;

  const HttpBodyTooLargeException(this.maxBytes);

  @override
  String toString() {
    final maxMegabytes = maxBytes / (1024 * 1024);
    return 'HTTP response exceeded ${maxMegabytes.toStringAsFixed(1)} MB.';
  }
}

Future<String> readUtf8HttpBody(
  HttpClientResponse response, {
  required int maxBytes,
  required Duration timeout,
}) {
  return readUtf8ByteStream(
    response,
    contentLength: response.contentLength,
    maxBytes: maxBytes,
    timeout: timeout,
  );
}

Future<String> readUtf8ByteStream(
  Stream<List<int>> stream, {
  int contentLength = -1,
  required int maxBytes,
  required Duration timeout,
}) async {
  if (contentLength > maxBytes) {
    throw HttpBodyTooLargeException(maxBytes);
  }

  final bytes = BytesBuilder(copy: false);
  var byteCount = 0;

  await for (final chunk in stream.timeout(timeout)) {
    byteCount += chunk.length;

    if (byteCount > maxBytes) {
      throw HttpBodyTooLargeException(maxBytes);
    }

    bytes.add(chunk);
  }

  return utf8.decode(bytes.takeBytes(), allowMalformed: true);
}
