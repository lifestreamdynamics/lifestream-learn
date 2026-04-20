import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_constants.dart';
import '../../data/models/course.dart';
import '../../data/repositories/course_repository.dart';

/// Landing screen for the Designer tab: a list of the caller's own
/// courses + "Create course" CTA. Tapping a course opens the editor.
class DesignerHomeScreen extends StatefulWidget {
  const DesignerHomeScreen({required this.courseRepo, super.key});

  final CourseRepository courseRepo;

  @override
  State<DesignerHomeScreen> createState() => _DesignerHomeScreenState();
}

class _DesignerHomeScreenState extends State<DesignerHomeScreen> {
  Future<List<Course>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = widget.courseRepo
          .published(
            owned: true,
            publishedFilter: false,
            limit: AppConstants.designerListLimit,
          )
          .then((page) => page.items);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Designer')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('designer.create'),
        onPressed: () async {
          final created =
              await GoRouter.of(context).push<bool>('/designer/courses/new');
          if (created == true) _reload();
        },
        icon: const Icon(Icons.add),
        label: const Text('Create course'),
      ),
      body: FutureBuilder<List<Course>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snap.error.toString(),
                      key: const Key('designer.error'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _reload,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final courses = snap.data ?? <Course>[];
          if (courses.isEmpty) {
            return const Center(
              key: Key('designer.empty'),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'You have no courses yet. Tap "Create course" to start.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: courses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = courses[i];
                return Card(
                  key: Key('designer.course.${c.id}'),
                  child: ListTile(
                    title: Text(c.title),
                    subtitle: Text(
                      c.published ? 'Published' : 'Draft',
                      style: TextStyle(
                        color: c.published ? Colors.green : Colors.orange,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await GoRouter.of(context)
                          .push('/designer/courses/${c.id}');
                      _reload();
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
