import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/art/brand_empty_state.dart';
import '../../core/http/error_envelope.dart';
import '../../core/utils/duration_formatters.dart';
import '../../data/models/enrollment.dart';
import '../../data/models/user.dart';
import '../../data/repositories/course_repository.dart';

/// Body of the "Enrolled" tab inside `CoursesScreen`. Shows the caller's
/// own enrollments (server-filtered by `req.user.id`); tapping a row
/// routes to `/feed`, which will position on the last-watched video once
/// the feed supports deep-linking.
///
/// The empty-state copy is role-aware: learners see a "Switch to
/// Available" prompt; admins and designers — who don't enroll in
/// practice — see an explanatory blurb directing them to the Available
/// tab. This is the only role-dependent UI here.
class EnrolledCoursesBody extends StatefulWidget {
  const EnrolledCoursesBody({
    required this.courseRepo,
    required this.role,
    this.onSwitchToAvailable,
    super.key,
  });

  final CourseRepository courseRepo;
  final UserRole role;

  /// Called when the empty-state CTA is tapped. Parents (the tabbed
  /// `CoursesScreen`) wire this to a `TabController.animateTo` instead
  /// of a router navigation — keeps the tab switch snappy and within
  /// the same shell branch.
  final VoidCallback? onSwitchToAvailable;

  @override
  State<EnrolledCoursesBody> createState() => _EnrolledCoursesBodyState();
}

class _EnrolledCoursesBodyState extends State<EnrolledCoursesBody> {
  List<EnrollmentWithCourse>? _rows;
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
      final rows = await widget.courseRepo.myEnrollments();
      if (!mounted) return;
      setState(() {
        _rows = rows;
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!.message),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final rows = _rows ?? const <EnrollmentWithCourse>[];
    if (rows.isEmpty) {
      return _EmptyState(
        role: widget.role,
        onSwitchToAvailable: widget.onSwitchToAvailable,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final row = rows[i];
          final lastHint = row.lastPosMs != null
              ? 'Last watched at ${formatDurationMs(row.lastPosMs!)}'
              : 'Not started';
          return Card(
            key: Key('myCourses.row.${row.courseId}'),
            child: ListTile(
              leading: row.course.coverImageUrl != null
                  ? SizedBox(
                      width: 56,
                      height: 56,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          row.course.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                        ),
                      ),
                    )
                  : const Icon(Icons.school_rounded, size: 40),
              title: Text(row.course.title),
              subtitle: Text(lastHint),
              trailing: const Icon(Icons.play_arrow_rounded),
              // Slice P2 — fix the known UX gap where tapping an
              // enrolled course jumped to `/feed` instead of resuming.
              // If we know a last-watched video, deep-link straight
              // into the player at the saved position. Otherwise fall
              // back to the course detail screen so the learner can
              // pick a lesson.
              onTap: () {
                final lastVideoId = row.lastVideoId;
                if (lastVideoId != null) {
                  final t = row.lastPosMs ?? 0;
                  GoRouter.of(context)
                      .go('/videos/$lastVideoId/watch?t=$t');
                } else {
                  GoRouter.of(context).go('/courses/${row.courseId}');
                }
              },
            ),
          );
        },
      ),
    );
  }

}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.role, required this.onSwitchToAvailable});

  final UserRole role;
  final VoidCallback? onSwitchToAvailable;

  @override
  Widget build(BuildContext context) {
    final isLearner = role == UserRole.learner;
    return BrandEmptyState(
      key: const Key('myCourses.empty'),
      painter: EmptyEnrollmentsPainter(
        scheme: Theme.of(context).colorScheme,
      ),
      title: isLearner ? 'No enrollments yet' : 'Browse the catalog',
      subtitle: isLearner
          ? 'Find a course you love and tap Enroll to get started.'
          : "You don't enroll in courses — use the Available tab to browse the catalog.",
      action: isLearner
          ? ElevatedButton(
              key: const Key('myCourses.empty.browse'),
              onPressed: onSwitchToAvailable,
              child: const Text('Browse courses'),
            )
          : null,
    );
  }
}
