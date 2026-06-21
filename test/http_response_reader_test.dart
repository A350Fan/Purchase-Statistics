// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:purchase_statistics/data/http_response_reader.dart';

void main() {
  group('readUtf8ByteStream', () {
    test('reads a UTF-8 byte stream under the configured limit', () async {
      final body = await readUtf8ByteStream(
        Stream.fromIterable([utf8.encode('{"ok":true}')]),
        maxBytes: 32,
        timeout: const Duration(seconds: 1),
      );

      expect(body, '{"ok":true}');
    });

    test('rejects streams that exceed the configured limit', () async {
      await expectLater(
        readUtf8ByteStream(
          Stream.fromIterable([utf8.encode('12345'), utf8.encode('67890')]),
          maxBytes: 8,
          timeout: const Duration(seconds: 1),
        ),
        throwsA(isA<HttpBodyTooLargeException>()),
      );
    });

    test(
      'rejects responses with a too large content length before reading',
      () async {
        var wasListenedTo = false;
        final stream = Stream<List<int>>.multi((controller) {
          wasListenedTo = true;
          controller.close();
        });

        await expectLater(
          readUtf8ByteStream(
            stream,
            contentLength: 9,
            maxBytes: 8,
            timeout: const Duration(seconds: 1),
          ),
          throwsA(isA<HttpBodyTooLargeException>()),
        );
        expect(wasListenedTo, isFalse);
      },
    );
  });
}
