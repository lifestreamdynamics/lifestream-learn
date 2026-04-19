import 'package:flutter/material.dart';

import '../../data/repositories/admin_analytics_repository.dart';
import '../../data/repositories/admin_designer_application_repository.dart';
import '../../data/repositories/course_repository.dart';
import 'course_analytics_screen.dart';
import 'designer_applications_screen.dart';

/// Admin-only landing screen. Two-tab `TabBar`: Applications + Analytics.
/// The outer role gate lives in the router; this screen assumes the
/// caller is already an admin.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({
    required this.adminDesignerAppsRepo,
    required this.adminAnalyticsRepo,
    required this.courseRepo,
    super.key,
  });

  final AdminDesignerApplicationRepository adminDesignerAppsRepo;
  final AdminAnalyticsRepository adminAnalyticsRepo;
  final CourseRepository courseRepo;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          bottom: const TabBar(
            key: Key('admin.tabs'),
            tabs: [
              Tab(key: Key('admin.tab.applications'), text: 'Applications'),
              Tab(key: Key('admin.tab.analytics'), text: 'Analytics'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            DesignerApplicationsScreen(repo: adminDesignerAppsRepo),
            CourseAnalyticsScreen(
              analyticsRepo: adminAnalyticsRepo,
              courseRepo: courseRepo,
            ),
          ],
        ),
      ),
    );
  }
}
