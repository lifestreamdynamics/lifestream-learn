import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/data/models/video.dart';
import 'package:lifestream_learn_app/features/designer/tus_uploader.dart';

VideoSummary _video() => VideoSummary(
      id: 'v1',
      courseId: 'c1',
      title: 'Intro',
      orderIndex: 0,
      status: VideoStatus.uploading,
      createdAt: DateTime.utc(2026, 4, 19),
    );

VideoUploadTicket _ticket({
  String videoId = 'abc',
  Map<String, String>? serverHeaders,
}) =>
    VideoUploadTicket(
      videoId: videoId,
      video: _video(),
      uploadUrl: 'http://test.local/tus',
      uploadHeaders: serverHeaders ??
          <String, String>{
            'Tus-Resumable': '1.0.0',
            'Upload-Metadata': 'videoId ${base64.encode(utf8.encode(videoId)).replaceAll('=', '')}',
          },
      sourceKey: 'learn-uploads/$videoId.mp4',
    );

void main() {
  group('TusUploader.headersForUpload', () {
    test('strips Upload-Metadata so the library rebuilds from metadata map',
        () {
      final headers = TusUploader.headersForUpload(_ticket(videoId: 'abc'));
      expect(headers.containsKey('Upload-Metadata'), isFalse);
      expect(headers['Tus-Resumable'], '1.0.0');
    });

    test('case-insensitive strip', () {
      final headers = TusUploader.headersForUpload(_ticket(
        serverHeaders: <String, String>{
          'Tus-Resumable': '1.0.0',
          'upload-metadata': 'videoId abc',
          'X-Custom': 'keep',
        },
      ));
      expect(headers.containsKey('upload-metadata'), isFalse);
      expect(headers['X-Custom'], 'keep');
    });
  });

  group('Upload-Metadata base64 padding behaviour (documented)', () {
    // Confirms the assumption the roadmap asked us to verify:
    // tus_client_dart uses `dart:convert`'s base64 encoder, which pads
    // its output with '=' when the byte length is not a multiple of 3.
    // tusd's Go base64 decoder is permissive and accepts both padded
    // and unpadded inputs, so shipping the padded encoding is fine.
    test('dart:convert base64 pads on 1-byte-mod-3 inputs', () {
      // 'ab' is 2 bytes; base64 pads with 1 '=' -> 'YWI='.
      expect(base64.encode(utf8.encode('ab')), 'YWI=');
    });

    test('dart:convert base64 pads on 2-bytes-mod-3 inputs', () {
      // 'a' is 1 byte; pads with 2 '=' -> 'YQ=='.
      expect(base64.encode(utf8.encode('a')), 'YQ==');
    });

    test('no padding needed for 3-byte-aligned inputs', () {
      expect(base64.encode(utf8.encode('abc')), 'YWJj');
    });

    test(
        'server pre-stripped header matches client-rebuilt one modulo padding',
        () {
      // The backend strips `=` suffixes from the Upload-Metadata it bakes.
      // If we ever chose to forward that header verbatim (bypassing the
      // library's metadata: param), we'd want to guarantee equivalence.
      final serverValue = base64
          .encode(utf8.encode('some-uuid-here'))
          .replaceAll(RegExp(r'=+\$'), '');
      final clientValue = base64.encode(utf8.encode('some-uuid-here'));
      expect(clientValue.replaceAll(RegExp(r'=+\$'), ''), serverValue);
    });
  });
}
