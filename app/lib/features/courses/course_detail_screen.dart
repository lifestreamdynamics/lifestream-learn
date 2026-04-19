import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/http/error_envelope.dart';
import '../../data/models/course.dart';
import '../../data/models/video.dart';
import '../../data/repositories/course_repository.dart';

/// Course landing page: metadata + video list + enroll CTA.
class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({
    required this.courseId,
    required this.courseRepo,
    super.key,
  });

  final String courseId;
  final CourseRepository courseRepo;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  CourseDetail? _course;
  ApiException? _error;
  bool _loading = true;
  bool _enrolling = false;
  bool _enrolled = false;

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
      final course = await widget.courseRepo.getById(widget.courseId);
      if (!mounted) return;
      setState(() {
        _course = course;
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

  Future<void> _enroll() async {
    setState(() => _enrolling = true);
    try {
      await widget.courseRepo.enroll(widget.courseId);
      if (!mounted) return;
      setState(() {
        _enrolling = false;
        _enrolled = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enrolled!')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enrolling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enroll failed: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_course?.title ?? 'Course')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
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
    final course = _course!;
    // Learner-safe filter: READY only. Designers and admins would see more
    // once Slice E wires role awareness into this screen.
    final videos = course.videos
        .where((v) => v.status == VideoStatus.ready)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (course.coverImageUrl != null)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              course.coverImageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.grey.shade300),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          course.title,
          key: const Key('detail.title'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(course.description),
        const SizedBox(height: 16),
        if (_enrolled)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ElevatedButton(
                key: Key('detail.enrolled'),
                onPressed: null,
                child: Text('Enrolled ✓'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('detail.watch'),
                onPressed: () => GoRouter.of(context).go('/feed'),
                child: const Text('Watch in feed'),
              ),
            ],
          )
        else
          ElevatedButton(
            key: const Key('detail.enroll'),
            onPressed: _enrolling ? null : _enroll,
            child: _enrolling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enroll'),
          ),
        const SizedBox(height: 24),
        Text(
          'Videos (${videos.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...videos.map((v) => ListTile(
              key: Key('detail.video.${v.id}'),
              leading: const Icon(Icons.play_circle_outline),
              title: Text(v.title),
              subtitle: v.durationMs != null
                  ? Text(_formatDuration(v.durationMs!))
                  : null,
            )),
      ],
    );
  }

  String _formatDuration(int ms) {
    final secs = ms ~/ 1000;
    final mm = (secs ~/ 60).toString().padLeft(2, '0');
    final ss = (secs % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}
