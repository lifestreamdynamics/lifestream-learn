import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:tus_client_dart/tus_client_dart.dart';

import '../../data/models/video.dart';

/// Signature for the TUS client factory. Production wires this to
/// `TusClient(...)`; tests substitute an in-memory stub that calls the
/// progress callback synthetically without touching the network.
typedef TusClientFactory = TusClient Function({required XFile file});

/// Thin façade over `tus_client_dart`. The designer authoring flow calls
/// [upload] with the upload ticket returned by `POST /api/videos` and
/// a progress callback. Resumability (tus) is built-in; interrupted
/// uploads resume from the last committed offset.
///
/// **Base64 padding note (Slice E roadmap):** `tus_client_dart` uses
/// `dart:convert`'s `base64.encode` which emits `=` padding on values
/// whose byte length is not a multiple of 3. The backend's tusd
/// pre-finish hook decodes with Go's permissive base64 library, so both
/// padded and unpadded values work. We forward the videoId via the
/// library's `metadata:` map unchanged. See
/// `test/features/designer/tus_uploader_test.dart` for the padding
/// verification.
class TusUploader {
  TusUploader({TusClientFactory? factory})
      : _factory = factory ?? _defaultFactory;

  final TusClientFactory _factory;

  static TusClient _defaultFactory({required XFile file}) {
    return TusClient(file, maxChunkSize: 5 * 1024 * 1024);
  }

  /// Uploads [file] using [ticket] and reports progress in [0, 1].
  ///
  /// Returns when the upload completes. Throws on unrecoverable errors.
  Future<void> upload({
    required VideoUploadTicket ticket,
    required XFile file,
    void Function(double fraction)? onProgress,
  }) async {
    final client = _factory(file: file);
    await client.upload(
      uri: Uri.parse(ticket.uploadUrl),
      metadata: <String, String>{'videoId': ticket.videoId},
      headers: headersForUpload(ticket),
      onProgress: (progress, _) {
        onProgress?.call(progress / 100);
      },
    );
  }

  /// Strips `Upload-Metadata` from the ticket's headers because the TUS
  /// client rebuilds that header from the `metadata:` map (and would
  /// overwrite ours anyway). Exposed so tests can assert the filtering.
  static Map<String, String> headersForUpload(VideoUploadTicket ticket) {
    return <String, String>{
      for (final entry in ticket.uploadHeaders.entries)
        if (entry.key.toLowerCase() != 'upload-metadata') entry.key: entry.value,
    };
  }
}
