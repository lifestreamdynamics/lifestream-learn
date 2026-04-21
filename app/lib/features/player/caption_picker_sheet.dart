import 'package:flutter/material.dart';

import '../../core/utils/bcp47_labels.dart';
import '../../data/models/video.dart';

/// Result returned by [showCaptionPicker].
///
/// Three exclusive states:
/// - `CaptionPickerResult.selected(language)` — user chose a language.
/// - `CaptionPickerResult.off()` — user chose "Off".
/// - `CaptionPickerResult.cancelled()` — user dismissed the sheet.
class CaptionPickerResult {
  const CaptionPickerResult.selected(String this.language)
      : off = false,
        cancelled = false;

  const CaptionPickerResult.off()
      : language = null,
        off = true,
        cancelled = false;

  const CaptionPickerResult.cancelled()
      : language = null,
        off = false,
        cancelled = true;

  final String? language;
  final bool off;
  final bool cancelled;
}

/// Shows a modal bottom sheet with an "Off" row plus one row per [tracks]
/// entry. Returns a [CaptionPickerResult] — never returns null; a swipe-down
/// dismiss maps to `CaptionPickerResult.cancelled()`.
Future<CaptionPickerResult> showCaptionPicker({
  required BuildContext context,
  required List<CaptionTrack> tracks,
  required String? currentLanguage,
}) async {
  final result = await showModalBottomSheet<CaptionPickerResult>(
    context: context,
    builder: (ctx) => _CaptionPickerSheet(
      tracks: tracks,
      currentLanguage: currentLanguage,
    ),
  );
  return result ?? const CaptionPickerResult.cancelled();
}

class _CaptionPickerSheet extends StatelessWidget {
  const _CaptionPickerSheet({
    required this.tracks,
    required this.currentLanguage,
  });

  final List<CaptionTrack> tracks;
  final String? currentLanguage;

  @override
  Widget build(BuildContext context) {
    final offSelected = currentLanguage == null;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sheet handle.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Caption language',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
          const Divider(height: 0),
          // "Off" row.
          ListTile(
            key: const Key('captionPicker.off'),
            title: const Text('Off'),
            trailing: offSelected
                ? const Icon(Icons.check, key: Key('captionPicker.off.check'))
                : null,
            onTap: () =>
                Navigator.of(context).pop(const CaptionPickerResult.off()),
          ),
          // One row per track.
          for (final track in tracks)
            ListTile(
              key: Key('captionPicker.lang.${track.language}'),
              title: Text(captionLanguageLabel(track.language)),
              trailing: currentLanguage == track.language
                  ? Icon(Icons.check,
                      key: Key('captionPicker.lang.${track.language}.check'))
                  : null,
              onTap: () => Navigator.of(context).pop(
                CaptionPickerResult.selected(track.language),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
