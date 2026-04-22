import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/http/error_envelope.dart';
import '../../core/utils/bcp47_labels.dart';
import '../../data/models/caption.dart';
import '../../data/repositories/caption_repository.dart';

const int _kMaxCaptionBytes = 512 * 1024;

/// Designer panel for managing caption tracks on a single video.
///
/// Renders a list of uploaded tracks and an "+ Add language" CTA that opens
/// a bottom sheet. Owns its own loading/error state — no BLoC required.
///
/// TODO(captions-default): defaultCaptionLanguage is not shown here because
/// VideoSummary doesn't include it yet. A future slice should expose it via
/// the video detail endpoint and wire [defaultCaptionLanguage] into the row
/// rendering. See IMPLEMENTATION_PLAN.md §5 caption slice notes (option c).
class CaptionsSection extends StatefulWidget {
  const CaptionsSection({
    required this.videoId,
    required this.captionRepo,
    this.defaultCaptionLanguage,
    this.onDefaultChanged,
    this.filePicker,
    super.key,
  });

  final String videoId;
  final CaptionRepository captionRepo;

  /// Current default caption language (BCP-47). Not rendered in Slice B —
  /// see TODO above.
  final String? defaultCaptionLanguage;

  /// Fired after a successful upload with `setDefault: true`, or when the
  /// default changes indirectly. Null means callers don't care.
  final ValueChanged<String?>? onDefaultChanged;

  /// Injected file-picker so widget tests can bypass the native platform
  /// channel (same pattern as [CourseEditorScreen.filePicker]).
  final Future<FilePickerResult?> Function()? filePicker;

  @override
  State<CaptionsSection> createState() => _CaptionsSectionState();
}

class _CaptionsSectionState extends State<CaptionsSection> {
  List<CaptionSummary>? _captions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final captions = await widget.captionRepo.list(widget.videoId);
      if (!mounted) return;
      setState(() {
        _captions = captions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddCaptionSheet(
        videoId: widget.videoId,
        captionRepo: widget.captionRepo,
        filePicker: widget.filePicker,
        onUploaded: (result) {
          if (!mounted) return;
          setState(() {
            _captions = [
              ...?_captions,
              CaptionSummary(
                language: result.language,
                bytes: result.bytes,
                uploadedAt: result.uploadedAt,
              ),
            ];
          });
          widget.onDefaultChanged?.call(result.language);
        },
      ),
    );
  }

  Future<void> _confirmDelete(CaptionSummary caption) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete caption?'),
        content: Text(
          'Remove ${captionLanguageLabel(caption.language)} captions? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await widget.captionRepo.delete(
        videoId: widget.videoId,
        language: caption.language,
      );
      if (!mounted) return;
      setState(() {
        _captions = (_captions ?? const <CaptionSummary>[])
            .where((c) => c.language != caption.language)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Delete failed: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Captions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('captions.addLanguage'),
                onPressed: _openAddSheet,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add language'),
              ),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _ErrorRow(message: _error!, onRetry: _load)
          else if (_captions == null || _captions!.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No captions yet — add a language to let learners follow along.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            for (final caption in _captions!)
              Card(
                key: Key('captions.row.${caption.language}'),
                child: ListTile(
                  title: Text(captionLanguageLabel(caption.language)),
                  subtitle: Text('${(caption.bytes / 1024).toStringAsFixed(1)} KB'),
                  trailing: IconButton(
                    key: Key('captions.delete.${caption.language}'),
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _confirmDelete(caption),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            key: const Key('captions.retry'),
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for picking a language + file and uploading.
class _AddCaptionSheet extends StatefulWidget {
  const _AddCaptionSheet({
    required this.videoId,
    required this.captionRepo,
    required this.onUploaded,
    this.filePicker,
  });

  final String videoId;
  final CaptionRepository captionRepo;
  final ValueChanged<CaptionUploadResult> onUploaded;
  final Future<FilePickerResult?> Function()? filePicker;

  @override
  State<_AddCaptionSheet> createState() => _AddCaptionSheetState();
}

class _AddCaptionSheetState extends State<_AddCaptionSheet> {
  String _language = kSupportedCaptionLanguages.first;
  bool _setDefault = false;
  PlatformFile? _pickedFile;
  bool _uploading = false;

  Future<void> _pickFile() async {
    final result = widget.filePicker != null
        ? await widget.filePicker!()
        : await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: const ['srt', 'vtt'],
            allowMultiple: false,
            withData: true,
          );
    if (result == null || result.files.isEmpty) return;
    setState(() => _pickedFile = result.files.single);
  }

  Future<void> _upload() async {
    final file = _pickedFile;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a file first.')),
      );
      return;
    }

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read file bytes.')),
      );
      return;
    }

    if (bytes.length > _kMaxCaptionBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caption too large (max 512 KB).')),
      );
      return;
    }

    final ext = (file.extension ?? '').toLowerCase();
    final contentType =
        ext == 'srt' ? 'application/x-subrip' : 'text/vtt';

    setState(() => _uploading = true);
    try {
      final result = await widget.captionRepo.upload(
        videoId: widget.videoId,
        language: _language,
        bytes: Uint8List.fromList(bytes),
        contentType: contentType,
        setDefault: _setDefault,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onUploaded(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Upload failed: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add captions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('captions.languagePicker'),
            initialValue: _language,
            decoration: const InputDecoration(labelText: 'Language'),
            items: kSupportedCaptionLanguages
                .map(
                  (code) => DropdownMenuItem<String>(
                    value: code,
                    child: Text(captionLanguageLabel(code)),
                  ),
                )
                .toList(),
            onChanged: _uploading
                ? null
                : (v) {
                    if (v != null) setState(() => _language = v);
                  },
          ),
          CheckboxListTile(
            key: const Key('captions.setDefault'),
            value: _setDefault,
            onChanged:
                _uploading ? null : (v) => setState(() => _setDefault = v ?? false),
            title: const Text('Set as default'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('captions.chooseFile'),
            onPressed: _uploading ? null : _pickFile,
            icon: const Icon(Icons.attach_file_rounded),
            label: Text(
              _pickedFile != null ? _pickedFile!.name : 'Choose file (.srt or .vtt)',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('captions.cancel'),
                onPressed:
                    _uploading ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                key: const Key('captions.upload'),
                onPressed: _uploading ? null : _upload,
                child: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Upload'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
