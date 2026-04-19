import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/course_repository.dart';

/// Create-course form. On submit: POST /api/courses → navigates to the
/// editor for the newly created course.
class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({required this.courseRepo, super.key});

  final CourseRepository courseRepo;

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _coverUrl = TextEditingController();
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _coverUrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final course = await widget.courseRepo.create(
        title: _title.text.trim(),
        description: _description.text.trim(),
        coverImageUrl:
            _coverUrl.text.trim().isEmpty ? null : _coverUrl.text.trim(),
      );
      if (!mounted) return;
      // Navigate to editor and signal creation back to the home screen.
      GoRouter.of(context).pop(true);
      await GoRouter.of(context).push('/designer/courses/${course.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create course')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _title,
                key: const Key('create.title'),
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : (v.trim().length > 200 ? 'Max 200 characters' : null),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                key: const Key('create.description'),
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Description is required'
                    : (v.trim().length > 2000 ? 'Max 2000 characters' : null),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _coverUrl,
                key: const Key('create.coverUrl'),
                decoration: const InputDecoration(
                  labelText: 'Cover image URL (optional)',
                ),
              ),
              if (_submitError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _submitError!,
                  key: const Key('create.error'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('create.submit'),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
