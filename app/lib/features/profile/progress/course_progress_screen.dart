import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/http/error_envelope.dart';
import '../../../data/models/progress.dart';
import '../../../data/repositories/progress_repository.dart';

/// Slice P2 — deep-dive course progress screen reached via the
/// "Details" button on an `EnrolledCourseCard`. Shows the full per-
/// lesson breakdown that the inline expansion also shows, but on a
/// dedicated screen with more room. Tapping a lesson deep-links to the
/// lesson review screen (`/courses/:courseId/lessons/:videoId/review`).
class CourseProgressScreen extends StatefulWidget {
  const CourseProgressScreen({
    required this.courseId,
    required this.progressRepo,
    super.key,
  });

  final String courseId;
  final ProgressRepository progressRepo;

  @override
  State<CourseProgressScreen> createState() => _CourseProgressScreenState();
}

class _CourseProgressScreenState extends State<CourseProgressScreen> {
  CourseProgressDetail? _detail;
  ApiException? _error;
  bool _loading = true;

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
      final detail = await widget.progressRepo.fetchCourse(widget.courseId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final err = _error;
    if (err != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Course progress')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(err.message),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final detail = _detail!;
    final theme = Theme.of(context);
    final pct = (detail.completionPct.clamp(0.0, 1.0) * 100).round();
    final accuracyPct = detail.accuracy != null
        ? '${(detail.accuracy! * 100).round()}%'
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(detail.course.title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  key: const Key('courseProgress.header'),
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Overall', style: theme.textTheme.labelMedium),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: detail.completionPct.clamp(0.0, 1.0),
                          minHeight: 8,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$pct% complete · ${detail.videosCompleted}/${detail.videosTotal} lessons',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        if (detail.grade != null && accuracyPct != null)
                          Text(
                            'Grade ${detail.grade!.label} · $accuracyPct '
                            '(${detail.cuesCorrect}/${detail.cuesAttempted} cues)',
                            key: const Key('courseProgress.header.grade'),
                            style: theme.textTheme.bodyMedium,
                          )
                        else
                          Text(
                            'No cue attempts yet',
                            style: theme.textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverList.separated(
              itemCount: detail.lessons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) => _LessonRow(
                lesson: detail.lessons[i],
                courseId: widget.courseId,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson, required this.courseId});
  final LessonProgressSummary lesson;
  final String courseId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = lesson.cuesAttempted == 0
        ? 'Not attempted'
        : '${lesson.cuesCorrect}/${lesson.cuesAttempted} correct'
            '${lesson.grade != null ? ' · ${lesson.grade!.label}' : ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        key: Key('courseProgress.lesson.${lesson.videoId}'),
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(
            lesson.completed
                ? Icons.check_circle_outline_rounded
                : Icons.play_circle_outline_rounded,
            color: lesson.completed
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          title: Text(lesson.title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push(
            '/courses/$courseId/lessons/${lesson.videoId}/review',
          ),
        ),
      ),
    );
  }
}
