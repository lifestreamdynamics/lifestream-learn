import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_event.dart';
import '../../core/auth/auth_state.dart';
import '../../data/models/user.dart';

/// Profile tab: user identity + log-out + (learner-only) "Apply to
/// become a course designer" link. Designer-application flow is stubbed
/// for now; Slice F wires it through to `/api/designer-applications`.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! Authenticated) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = state.user;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  user.displayName,
                  key: const Key('profile.displayName'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  key: const Key('profile.email'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Chip(
                  key: const Key('profile.role'),
                  label: Text(user.role.label),
                ),
                const Divider(height: 32),
                if (user.role == UserRole.learner)
                  ListTile(
                    key: const Key('profile.applyDesigner'),
                    leading: const Icon(Icons.school),
                    title: const Text('Apply to become a course designer'),
                    onTap: () =>
                        GoRouter.of(context).go('/designer-application'),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  key: const Key('profile.logout'),
                  onPressed: () =>
                      context.read<AuthBloc>().add(const LoggedOut()),
                  child: const Text('Log out'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Slice F: DesignerApplicationStubScreen has been replaced by the real
// `DesignerApplicationScreen` in `features/designer/designer_application_screen.dart`.
// The router points `/designer-application` at the real implementation.
