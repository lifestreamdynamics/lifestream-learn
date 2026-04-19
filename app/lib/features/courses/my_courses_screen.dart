import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/http/error_envelope.dart';
import '../../data/models/enrollment.dart';
import '../../data/repositories/course_repository.dart';

/// Learner's own enrollments — a single-column list with last-watched
/// hints. Tapping a card routes to `/feed` (Slice E may add deep-linking
/// to `lastVideoId` once the feed can position itself on a specific id).
class MyCoursesScreen extends StatefulWidget {
  const MyCoursesScreen({required this.courseRepo, super.key});

  final CourseRepository courseRepo;

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> {
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
    return Scaffold(
      appBar: AppBar(title: const Text('My courses')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No enrollments yet.', key: Key('myCourses.empty')),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => GoRouter.of(context).go('/courses'),
              child: const Text('Browse courses'),
            ),
          ],
        ),
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
              ? 'Last watched at ${_formatMs(row.lastPosMs!)}'
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
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.grey.shade300),
                        ),
                      ),
                    )
                  : const Icon(Icons.school, size: 40),
              title: Text(row.course.title),
              subtitle: Text(lastHint),
              trailing: const Icon(Icons.play_arrow),
              onTap: () => GoRouter.of(context).go('/feed'),
            ),
          );
        },
      ),
    );
  }

  String _formatMs(int ms) {
    final secs = ms ~/ 1000;
    final mm = (secs ~/ 60).toString().padLeft(2, '0');
    final ss = (secs % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}
