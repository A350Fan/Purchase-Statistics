// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Wird geworfen, wenn eine HTTP-Antwort groesser ist als fuer diesen Endpoint
/// erwartet.
class HttpBodyTooLargeException implements Exception {
  final int maxBytes;

  const HttpBodyTooLargeException(this.maxBytes);

  @override
  String toString() {
    final maxMegabytes = maxBytes / (1024 * 1024);
    return 'HTTP response exceeded ${maxMegabytes.toStringAsFixed(1)} MB.';
  }
}

/// Liest eine `HttpClientResponse` als UTF-8-String mit Groessenlimit und
/// Timeout.
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

/// Stream-basierte Variante, die auch in Tests ohne echten HttpClient genutzt
/// werden kann.
Future<String> readUtf8ByteStream(
  Stream<List<int>> stream, {
  int contentLength = -1,
  required int maxBytes,
  required Duration timeout,
}) async {
  // Wenn der Server Content-Length setzt, kann eine zu grosse Antwort schon vor
  // dem Lesen abgelehnt werden.
  if (contentLength > maxBytes) {
    throw HttpBodyTooLargeException(maxBytes);
  }

  final bytes = BytesBuilder(copy: false);
  var byteCount = 0;

  await for (final chunk in stream.timeout(timeout)) {
    byteCount += chunk.length;

    // Das Limit wird auch waehrend des Lesens geprueft, weil Content-Length
    // fehlen oder falsch sein kann.
    if (byteCount > maxBytes) {
      throw HttpBodyTooLargeException(maxBytes);
    }

    bytes.add(chunk);
  }

  return utf8.decode(bytes.takeBytes(), allowMalformed: true);
}
