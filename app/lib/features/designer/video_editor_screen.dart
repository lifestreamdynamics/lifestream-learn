import 'package:flutter/material.dart';

import '../../data/models/cue.dart';
import '../../data/models/video.dart';
import '../../data/repositories/caption_repository.dart';
import '../../data/repositories/cue_repository.dart';
import '../../data/repositories/enrollment_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../feed/video_controller_cache.dart';
import '../player/learn_video_player.dart';
import 'captions_section.dart';
import 'cue_form_sheet.dart';

/// Designer authoring surface for a single video.
///
/// Shows the player (in authoring mode: no cue scheduler, no auto-play)
/// with a scrubber + timeline of existing cue markers, and a CTA to add
/// a cue at the current time. Taps on a cue marker open the same form
/// pre-filled for editing.
///
/// Per CLAUDE.md: the MediaCodec decoder budget on Android is tight;
/// authoring uses a dedicated cache with `capacity=1` so we don't blow
/// past the limit when the designer also has the feed in the background.
class VideoEditorScreen extends StatefulWidget {
  const VideoEditorScreen({
    required this.videoId,
    required this.videoRepo,
    required this.cueRepo,
    required this.captionRepo,
    required this.enrollmentRepo,
    super.key,
  });

  final String videoId;
  final VideoRepository videoRepo;
  final CueRepository cueRepo;
  final CaptionRepository captionRepo;
  final EnrollmentRepository enrollmentRepo;

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  VideoSummary? _video;
  List<Cue>? _cues;
  String? _error;
  late final VideoControllerCache _cache;

  @override
  void initState() {
    super.initState();
    _cache = VideoControllerCache(capacity: 1);
    _load();
  }

  @override
  void dispose() {
    _cache.evictAll();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        widget.videoRepo.get(widget.videoId),
        widget.cueRepo.listForVideo(widget.videoId),
      ]);
      if (!mounted) return;
      setState(() {
        _video = results[0] as VideoSummary;
        _cues = List<Cue>.from(results[1] as List<Cue>)
          ..sort((a, b) => a.atMs.compareTo(b.atMs));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _openCueForm({Cue? existing, int? atMs}) async {
    final result = await showModalBottomSheet<CueFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CueFormSheet(existing: existing),
    );
    if (result == null) return;
    try {
      if (existing == null) {
        final cue = await widget.cueRepo.create(
          widget.videoId,
          atMs: atMs ?? 0,
          type: result.type,
          payload: result.payload,
          pause: result.pause,
        );
        if (!mounted) return;
        setState(() {
          _cues = [...?_cues, cue]..sort((a, b) => a.atMs.compareTo(b.atMs));
        });
      } else {
        final cue = await widget.cueRepo.update(existing.id, <String, dynamic>{
          'payload': result.payload,
          'pause': result.pause,
        });
        if (!mounted) return;
        setState(() {
          _cues = (_cues ?? <Cue>[])
              .map((c) => c.id == cue.id ? cue : c)
              .toList()
            ..sort((a, b) => a.atMs.compareTo(b.atMs));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cue save failed: $e')),
      );
    }
  }

  Future<void> _deleteCue(Cue cue) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete cue?'),
        content: const Text('This cannot be undone.'),
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
    if (confirm != true) return;
    try {
      await widget.cueRepo.delete(cue.id);
      if (!mounted) return;
      setState(() {
        _cues = (_cues ?? const <Cue>[]).where((c) => c.id != cue.id).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final cues = _cues;
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!),
          ),
        ),
      );
    }
    if (video == null || cues == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(video.title),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: LearnVideoPlayer(
                video: video,
                courseId: video.courseId,
                videoRepo: widget.videoRepo,
                enrollmentRepo: widget.enrollmentRepo,
                controllerCache: _cache,
                autoPlayWhenVisible: false,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _CueTimeline(
              cues: cues,
              durationMs: video.durationMs ?? 0,
              onTapCue: (cue) => _openCueForm(existing: cue),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('video.addCue'),
                      onPressed: () => _openCueForm(atMs: 0),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add cue at current time'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(8),
            sliver: SliverList.list(
              children: [
                for (final c in cues)
                  Card(
                    key: Key('video.cue.${c.id}'),
                    child: ListTile(
                      leading: Icon(_iconFor(c.type)),
                      title: Text(_labelFor(c.type)),
                      subtitle: Text(_formatMs(c.atMs)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: Key('video.cue.${c.id}.edit'),
                            icon: const Icon(Icons.edit_rounded),
                            onPressed: () => _openCueForm(existing: c),
                          ),
                          IconButton(
                            key: Key('video.cue.${c.id}.delete'),
                            icon: const Icon(Icons.delete_rounded),
                            onPressed: () => _deleteCue(c),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: CaptionsSection(
              key: const Key('video.captionsSection'),
              videoId: widget.videoId,
              captionRepo: widget.captionRepo,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(CueType t) {
    switch (t) {
      case CueType.mcq:
        return Icons.quiz_rounded;
      case CueType.blanks:
        return Icons.edit_note_rounded;
      case CueType.matching:
        return Icons.compare_arrows_rounded;
      case CueType.voice:
        return Icons.mic_rounded;
    }
  }

  String _labelFor(CueType t) {
    switch (t) {
      case CueType.mcq:
        return 'MCQ';
      case CueType.blanks:
        return 'Blanks';
      case CueType.matching:
        return 'Matching';
      case CueType.voice:
        return 'Voice';
    }
  }

  String _formatMs(int ms) {
    final total = Duration(milliseconds: ms);
    final mm = total.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = total.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

/// Horizontal bar showing cue markers proportionally positioned by
/// `atMs / durationMs`. Rendered via `CustomPaint` so the marker layout
/// adapts to the bar's width.
///
/// Exposed under the test-only name `CueTimelineForTest` so the widget
/// test file can render just the timeline without booting the platform
/// video plugin.
@visibleForTesting
class CueTimelineForTest extends StatelessWidget {
  const CueTimelineForTest({
    required this.cues,
    required this.durationMs,
    required this.onTapCue,
    super.key,
  });

  final List<Cue> cues;
  final int durationMs;
  final ValueChanged<Cue> onTapCue;

  @override
  Widget build(BuildContext context) =>
      _CueTimeline(cues: cues, durationMs: durationMs, onTapCue: onTapCue);
}

class _CueTimeline extends StatelessWidget {
  const _CueTimeline({
    required this.cues,
    required this.durationMs,
    required this.onTapCue,
  });

  final List<Cue> cues;
  final int durationMs;
  final ValueChanged<Cue> onTapCue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
              if (durationMs > 0)
                for (final c in cues)
                  Positioned(
                    left: (c.atMs / durationMs) * w - 6,
                    top: 8,
                    bottom: 8,
                    child: GestureDetector(
                      key: Key('video.marker.${c.id}'),
                      onTap: () => onTapCue(c),
                      child: Container(
                        width: 12,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
