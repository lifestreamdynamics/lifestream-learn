import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../data/models/user.dart';
import '../../data/repositories/course_repository.dart';
import 'available_courses_body.dart';
import 'enrolled_courses_body.dart';

/// Unified landing for the bottom-nav "Courses" slot across all roles.
///
/// Two tabs:
///   - **Enrolled**: the caller's own enrollments (empty for non-learners
///     by design — the backend returns `[]` for admins/designers and the
///     empty-state copy explains why).
///   - **Available**: the published-course catalog. Shared by every role;
///     admins also see unpublished-owned filters via course-detail flows.
///
/// Course-designers and admins get a "Create course" FAB on the Available
/// tab that routes to the existing `/designer/courses/new` editor flow.
/// This replaces the dedicated `DesignerHomeScreen` previously hosted
/// under `/designer`; that route is kept as a redirect to `/courses` so
/// old deep-links don't break.
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({required this.courseRepo, super.key});

  final CourseRepository courseRepo;

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, next) => prev.runtimeType != next.runtimeType,
      builder: (context, authState) {
        // The route is only reachable while authenticated (router
        // redirect), but BlocBuilder needs a fallback anyway.
        final role = authState is Authenticated
            ? authState.user.role
            : UserRole.learner;
        final canCreate =
            role == UserRole.admin || role == UserRole.courseDesigner;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Courses'),
            bottom: TabBar(
              key: const Key('courses.tabs'),
              controller: _tabs,
              tabs: const [
                Tab(
                  key: Key('courses.tab.enrolled'),
                  text: 'Enrolled',
                ),
                Tab(
                  key: Key('courses.tab.available'),
                  text: 'Available',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              EnrolledCoursesBody(
                courseRepo: widget.courseRepo,
                role: role,
                onSwitchToAvailable: () => _tabs.animateTo(1),
              ),
              AvailableCoursesBody(courseRepo: widget.courseRepo),
            ],
          ),
          floatingActionButton: canCreate
              ? AnimatedBuilder(
                  animation: _tabs,
                  builder: (context, _) {
                    // Only show the Create FAB when the user is on the
                    // Available tab — it's not relevant to Enrolled.
                    if (_tabs.index != 1) return const SizedBox.shrink();
                    return FloatingActionButton.extended(
                      key: const Key('courses.create'),
                      onPressed: () =>
                          GoRouter.of(context).push('/designer/courses/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Create course'),
                    );
                  },
                )
              : null,
        );
      },
    );
  }
}
