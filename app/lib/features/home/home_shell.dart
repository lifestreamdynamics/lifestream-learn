import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_event.dart';
import '../../core/auth/auth_state.dart';
import '../../data/models/user.dart';

/// Placeholder landing screen for all roles. Slice D replaces this with a
/// real `BottomNavigationBar` + feed + designer/admin tabs.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lifestream Learn')),
      body: Center(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is! Authenticated) {
              return const CircularProgressIndicator();
            }
            final user = state.user;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome, ${user.displayName} (${user.role.label})',
                    key: const Key('home.welcome'),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    key: const Key('home.logout'),
                    onPressed: () =>
                        context.read<AuthBloc>().add(const LoggedOut()),
                    child: const Text('Log out'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
