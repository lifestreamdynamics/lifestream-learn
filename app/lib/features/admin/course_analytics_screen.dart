import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../config/app_constants.dart';
import '../../core/art/brand_empty_state.dart';
import '../../core/platform/flag_secure.dart';
import '../../data/models/course.dart';
import '../../data/models/course_analytics.dart';
import '../../data/repositories/admin_analytics_repository.dart';
import '../../data/repositories/course_repository.dart';
import '../shared/friendly_error_screen.dart';

/// Admin-only course analytics dashboard. Picks a course from a
/// dropdown and renders aggregates from
/// `GET /api/admin/analytics/courses/:id`:
/// - `totalViews` — integer.
/// - `completionRate` — rendered as a percentage.
/// - `perCueTypeAccuracy` — DataTable with one row per cue type; null
///   accuracy renders as "No attempts yet".
///
/// The course list is pulled via `CourseRepository.published` with the
/// `publishedFilter: false` toggle so admins see both published and
/// unpublished owned courses. Designer-level `owned` scoping doesn't
/// apply here — admins see all.
class CourseAnalyticsScreen extends StatefulWidget {
  const CourseAnalyticsScreen({
    required this.analyticsRepo,
    required this.courseRepo,
    super.key,
  });

  final AdminAnalyticsRepository analyticsRepo;
  final CourseRepository courseRepo;

  @override
  State<CourseAnalyticsScreen> createState() => _CourseAnalyticsScreenState();
}

class _CourseAnalyticsScreenState extends State<CourseAnalyticsScreen> {
  bool _loadingCourses = true;
  List<Course> _courses = <Course>[];
  Object? _coursesError;

  String? _selectedCourseId;
  bool _loadingAnalytics = false;
  CourseAnalytics? _analytics;
  Object? _analyticsError;

  @override
  void initState() {
    super.initState();
    FlagSecure.enable();
    _loadCourses();
  }

  @override
  void dispose() {
    FlagSecure.disable();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _loadingCourses = true;
      _coursesError = null;
    });
    try {
      // For admin dashboards we want BOTH published and unpublished in
      // the picker — pass `publishedFilter: false` so the server returns
      // the wider list. (The underlying `/api/courses` route serves the
      // admin the full set when authenticated.)
      final page = await widget.courseRepo.published(
        limit: AppConstants.designerListLimit,
        publishedFilter: false,
      );
      if (!mounted) return;
      setState(() {
        _courses = page.items;
        _loadingCourses = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _coursesError = e;
        _loadingCourses = false;
      });
    }
  }

  Future<void> _loadAnalytics(String courseId) async {
    setState(() {
      _selectedCourseId = courseId;
      _loadingAnalytics = true;
      _analyticsError = null;
    });
    try {
      final result = await widget.analyticsRepo.course(courseId);
      if (!mounted) return;
      setState(() {
        _analytics = result;
        _loadingAnalytics = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyticsError = e;
        _loadingAnalytics = false;
      });
    }
  }

  String _formatAccuracy(double? v) {
    if (v == null) return 'No attempts yet';
    final pct = (v * 100).toStringAsFixed(1);
    return '$pct%';
  }

  String _formatCompletion(double v) {
    final pct = (v * 100).toStringAsFixed(1);
    return '$pct%';
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCourses) {
      return Skeletonizer(
        enabled: true,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              _PickerSkeleton(),
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Bone.text(words: 4),
                      SizedBox(height: 12),
                      Bone.multiText(lines: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_coursesError != null) {
      return FriendlyErrorBody(
        title: "Couldn't load courses",
        message: 'The course list failed to load. Retry in a moment.',
        debugError: _coursesError,
        onRetry: _loadCourses,
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPicker(),
          const SizedBox(height: 16),
          _buildAnalyticsPanel(context),
        ],
      ),
    );
  }

  Widget _buildPicker() {
    if (_courses.isEmpty) {
      return BrandEmptyState(
        key: const Key('admin.analytics.noCourses'),
        painter: EmptySearchPainter(
          scheme: Theme.of(context).colorScheme,
        ),
        title: 'No courses exist yet',
        subtitle:
            'Course analytics will appear here once a designer publishes a course.',
      );
    }
    return DropdownButtonFormField<String>(
      key: const Key('admin.analytics.picker'),
      initialValue: _selectedCourseId,
      decoration: const InputDecoration(
        labelText: 'Course',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final c in _courses)
          DropdownMenuItem<String>(
            value: c.id,
            child: Text('${c.title}${c.published ? '' : ' (unpublished)'}'),
          ),
      ],
      onChanged: (v) {
        if (v != null) _loadAnalytics(v);
      },
    );
  }

  Widget _buildAnalyticsPanel(BuildContext context) {
    if (_selectedCourseId == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Pick a course to see its analytics.',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_loadingAnalytics) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_analyticsError != null) {
      return FriendlyErrorBody(
        title: "Couldn't load analytics",
        message: "The analytics for this course couldn't be fetched.",
        debugError: _analyticsError,
        onRetry: () => _loadAnalytics(_selectedCourseId!),
      );
    }
    final a = _analytics;
    if (a == null) {
      return const SizedBox.shrink();
    }
    return Card(
      key: const Key('admin.analytics.card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    key: const Key('admin.analytics.totalViews'),
                    label: 'Total views',
                    value: '${a.totalViews}',
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    key: const Key('admin.analytics.completionRate'),
                    label: 'Completion rate',
                    value: _formatCompletion(a.completionRate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Per cue-type accuracy',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DataTable(
              key: const Key('admin.analytics.accuracy'),
              columns: const [
                DataColumn(label: Text('Cue type')),
                DataColumn(label: Text('Accuracy')),
              ],
              rows: [
                DataRow(
                  key: const ValueKey('admin.analytics.row.MCQ'),
                  cells: [
                    const DataCell(Text('MCQ')),
                    DataCell(Text(_formatAccuracy(a.perCueTypeAccuracy.mcq))),
                  ],
                ),
                DataRow(
                  key: const ValueKey('admin.analytics.row.BLANKS'),
                  cells: [
                    const DataCell(Text('BLANKS')),
                    DataCell(Text(_formatAccuracy(a.perCueTypeAccuracy.blanks))),
                  ],
                ),
                DataRow(
                  key: const ValueKey('admin.analytics.row.MATCHING'),
                  cells: [
                    const DataCell(Text('MATCHING')),
                    DataCell(
                      Text(_formatAccuracy(a.perCueTypeAccuracy.matching)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _PickerSkeleton extends StatelessWidget {
  const _PickerSkeleton();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 56,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Bone.text(words: 4),
        ),
      ),
    );
  }
}
