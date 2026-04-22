import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/http/error_envelope.dart';
import '../../../data/models/progress.dart';
import '../../../data/repositories/progress_repository.dart';

/// Slice P2 — per-course progress card in the profile screen.
///
/// Renders the course cover + title, a horizontal progress bar, grade
/// chip (letter + percentage — never colour-alone), and a Resume/Start
/// button that deep-links into the player at the correct position. An
/// `ExpansionTile` lazily loads the per-lesson detail on first tap.
class EnrolledCourseCard extends StatefulWidget {
  const EnrolledCourseCard({
    required this.summary,
    required this.progressRepo,
    super.key,
  });

  final CourseProgressSummary summary;
  final ProgressRepository progressRepo;

  @override
  State<EnrolledCourseCard> createState() => _EnrolledCourseCardState();
}

class _EnrolledCourseCardState extends State<EnrolledCourseCard> {
  CourseProgressDetail? _detail;
  ApiException? _detailError;
  bool _expanded = false;
  bool _loading = false;

  Future<void> _onExpansionChanged(bool expanded) async {
    setState(() => _expanded = expanded);
    if (!expanded) return;
    if (_detail != null || _loading) return;
    setState(() => _loading = true);
    try {
      final detail =
          await widget.progressRepo.fetchCourse(widget.summary.course.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _detailError = e;
        _loading = false;
      });
    }
  }

  void _onResume(BuildContext context) {
    final lastVideoId = widget.summary.lastVideoId;
    final lastPosMs = widget.summary.lastPosMs ?? 0;
    if (lastVideoId != null) {
      // Deep-link with a ?t=<ms> query param — the player reads this on
      // init and seeks once the controller is ready.
      context.push('/videos/$lastVideoId/watch?t=$lastPosMs');
      return;
    }
    // No last-watched position recorded: either the learner hasn't
    // started, or the enrollment is brand new. If we've already loaded
    // the lesson detail, punch into the first lesson directly; otherwise
    // route to the course detail screen so they can pick.
    final firstLesson = _detail?.lessons.firstOrNull;
    if (firstLesson != null) {
      context.push('/videos/${firstLesson.videoId}/watch?t=0');
    } else {
      context.push('/courses/${widget.summary.course.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final theme = Theme.of(context);
    final pct = (s.completionPct.clamp(0.0, 1.0) * 100).round();
    final accuracyPct = s.accuracy != null
        ? '${(s.accuracy! * 100).round()}%'
        : null;
    final gradeChipLabel = s.grade != null && accuracyPct != null
        ? '${s.grade!.label} · $accuracyPct'
        : 'No attempts yet';
    final resumeLabel = s.lastVideoId != null ? 'Resume' : 'Start';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        key: Key('profile.course.${s.course.id}'),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _CoverImage(url: s.course.coverImageUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.course.title,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 4),
                        Semantics(
                          label:
                              '${s.videosCompleted} of ${s.videosTotal} lessons complete',
                          child: LinearProgressIndicator(
                            value: s.completionPct.clamp(0.0, 1.0),
                            minHeight: 6,
                            key: Key('profile.course.${s.course.id}.progress'),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '$pct% · ${s.videosCompleted}/${s.videosTotal}',
                              key: Key(
                                'profile.course.${s.course.id}.progressLabel',
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              key: Key(
                                'profile.course.${s.course.id}.gradeChip',
                              ),
                              label: Text(gradeChipLabel),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: Key('profile.course.${s.course.id}.details'),
                    onPressed: () =>
                        context.push('/courses/${s.course.id}/progress'),
                    child: const Text('Details'),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    key: Key('profile.course.${s.course.id}.resume'),
                    onPressed: () => _onResume(context),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(resumeLabel),
                  ),
                ],
              ),
            ),
            Theme(
              // Drop the internal divider ExpansionTile renders — the
              // parent Card already separates the section visually.
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: Key('profile.course.${s.course.id}.expand'),
                onExpansionChanged: _onExpansionChanged,
                title: Text(
                  _expanded ? 'Hide lessons' : 'Show lessons',
                  style: theme.textTheme.labelLarge,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                children: _buildLessonTiles(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLessonTiles(BuildContext context) {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    final err = _detailError;
    if (err != null) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(err.message),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _onExpansionChanged(true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ];
    }
    final detail = _detail;
    if (detail == null || detail.lessons.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No lessons yet.'),
        ),
      ];
    }
    return detail.lessons
        .map((l) => _LessonTile(lesson: l, courseId: widget.summary.course.id))
        .toList(growable: false);
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return const SizedBox(
        width: 56,
        height: 56,
        child: Icon(Icons.school_outlined, size: 36),
      );
    }
    return SizedBox(
      width: 56,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson, required this.courseId});
  final LessonProgressSummary lesson;
  final String courseId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = lesson.cuesAttempted == 0
        ? 'Not attempted'
        : '${lesson.cuesCorrect}/${lesson.cuesAttempted} correct'
            '${lesson.grade != null ? ' · ${lesson.grade!.label}' : ''}';
    return ListTile(
      key: Key('profile.lesson.${lesson.videoId}'),
      dense: true,
      leading: Icon(
        lesson.completed
            ? Icons.check_circle_outline_rounded
            : Icons.play_circle_outline_rounded,
        color: lesson.completed
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(lesson.title, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push(
        '/courses/$courseId/lessons/${lesson.videoId}/review',
      ),
    );
  }
}
