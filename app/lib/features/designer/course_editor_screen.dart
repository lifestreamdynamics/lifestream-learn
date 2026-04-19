import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/course.dart';
import '../../data/models/video.dart';
import '../../data/repositories/course_repository.dart';
import '../../data/repositories/video_repository.dart';
import 'tus_uploader.dart';
import 'video_status_poller.dart';

/// Edit-a-course screen: title/description inline editing, the video
/// list, and an "Upload video" CTA. Tapping a video opens the cue
/// editor.
class CourseEditorScreen extends StatefulWidget {
  const CourseEditorScreen({
    required this.courseId,
    required this.courseRepo,
    required this.videoRepo,
    this.uploader,
    this.filePicker,
    super.key,
  });

  final String courseId;
  final CourseRepository courseRepo;
  final VideoRepository videoRepo;

  /// Injected so widget tests can sidestep the native file picker + tus
  /// network calls.
  final TusUploader? uploader;
  final Future<FilePickerResult?> Function()? filePicker;

  @override
  State<CourseEditorScreen> createState() => _CourseEditorScreenState();
}

class _CourseEditorScreenState extends State<CourseEditorScreen> {
  Future<CourseDetail>? _future;
  double? _uploadProgress;
  String? _uploadError;
  VideoStatusPoller? _poller;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _poller?.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = widget.courseRepo.getById(widget.courseId);
    });
  }

  Future<void> _startUpload(CourseDetail course) async {
    setState(() {
      _uploadError = null;
      _uploadProgress = 0.0;
    });
    try {
      final pick = widget.filePicker != null
          ? await widget.filePicker!()
          : await FilePicker.platform.pickFiles(
              type: FileType.video,
              allowMultiple: false,
            );
      if (pick == null || pick.files.isEmpty) {
        setState(() => _uploadProgress = null);
        return;
      }
      final picked = pick.files.single;
      final path = picked.path;
      if (path == null) {
        setState(() {
          _uploadProgress = null;
          _uploadError = 'File has no local path';
        });
        return;
      }

      final title = picked.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      final orderIndex = course.videos.length;
      final ticket = await widget.videoRepo.createVideo(
        courseId: widget.courseId,
        title: title,
        orderIndex: orderIndex,
      );

      final uploader = widget.uploader ?? TusUploader();
      await uploader.upload(
        ticket: ticket,
        file: XFile(path),
        onProgress: (fraction) {
          if (!mounted) return;
          setState(() => _uploadProgress = fraction);
        },
      );

      // Upload complete; kick off status polling so the UI transitions
      // UPLOADING → TRANSCODING → READY without requiring a manual
      // refresh.
      _poller?.dispose();
      final poller = VideoStatusPoller(
        videoId: ticket.videoId,
        videoRepo: widget.videoRepo,
      );
      _poller = poller;
      poller.addListener(() {
        if (!mounted) return;
        setState(() {});
        if (poller.isTerminal) {
          _reload();
        }
      });
      poller.start();
      if (mounted) setState(() => _uploadProgress = null);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadProgress = null;
        _uploadError = e.toString();
      });
    }
  }

  Future<void> _publish(CourseDetail course) async {
    try {
      await widget.courseRepo.publish(course.id);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Publish failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit course')),
      body: FutureBuilder<CourseDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snap.error.toString()),
              ),
            );
          }
          final course = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(course.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(course.description),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(
                    key: const Key('editor.status'),
                    label: Text(course.published ? 'Published' : 'Draft'),
                    backgroundColor:
                        course.published ? Colors.green.shade100 : null,
                  ),
                  const SizedBox(width: 8),
                  if (!course.published)
                    TextButton(
                      key: const Key('editor.publish'),
                      onPressed: () => _publish(course),
                      child: const Text('Publish'),
                    ),
                ],
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Videos', style: Theme.of(context).textTheme.titleMedium),
                  ElevatedButton.icon(
                    key: const Key('editor.upload'),
                    onPressed: _uploadProgress != null
                        ? null
                        : () => _startUpload(course),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload video'),
                  ),
                ],
              ),
              if (_uploadProgress != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  key: const Key('editor.upload.progress'),
                  value: _uploadProgress!.clamp(0.0, 1.0),
                ),
              ],
              if (_uploadError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _uploadError!,
                  key: const Key('editor.upload.error'),
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_poller != null && _poller!.current != null) ...[
                const SizedBox(height: 8),
                Text(
                  'New video status: ${_statusLabel(_poller!.current!.status)}',
                  key: const Key('editor.poller.status'),
                ),
              ],
              const SizedBox(height: 12),
              if (course.videos.isEmpty)
                const Text('No videos yet. Upload one to get started.')
              else
                for (final v in course.videos)
                  Card(
                    key: Key('editor.video.${v.id}'),
                    child: ListTile(
                      leading: _statusIcon(v.status),
                      title: Text(v.title),
                      subtitle: Text(_statusLabel(v.status)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: v.status == VideoStatus.ready
                          ? () {
                              GoRouter.of(context)
                                  .push('/designer/videos/${v.id}/edit');
                            }
                          : null,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusIcon(VideoStatus s) {
    switch (s) {
      case VideoStatus.ready:
        return const Icon(Icons.check_circle, color: Colors.green);
      case VideoStatus.uploading:
        return const Icon(Icons.cloud_upload, color: Colors.blue);
      case VideoStatus.transcoding:
        return const Icon(Icons.hourglass_top, color: Colors.orange);
      case VideoStatus.failed:
        return const Icon(Icons.error, color: Colors.red);
    }
  }

  String _statusLabel(VideoStatus s) {
    switch (s) {
      case VideoStatus.ready:
        return 'Ready';
      case VideoStatus.uploading:
        return 'Uploading';
      case VideoStatus.transcoding:
        return 'Transcoding';
      case VideoStatus.failed:
        return 'Failed';
    }
  }
}
