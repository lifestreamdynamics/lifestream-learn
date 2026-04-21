import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/auth/auth_bloc.dart';
import '../../../core/auth/auth_event.dart';
import '../../../core/http/error_envelope.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/me_repository.dart';

/// Bottom-sheet form for editing the profile. Slice P1 scope is just
/// `displayName`; future slices extend with more fields (e.g. avatar
/// picker, useGravatar toggle).
///
/// On success, the repo returns a fresh `User` which we dispatch via
/// `UserUpdated` so the cached auth state picks up the change without
/// a round-trip through `GET /api/auth/me`.
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({
    required this.user,
    required this.meRepo,
    super.key,
  });

  final User user;
  final MeRepository meRepo;

  /// Helper to present this sheet from a list-tile onTap. Returns the
  /// updated `User` when the save path completes, or null if the user
  /// dismissed without saving.
  static Future<User?> show({
    required BuildContext context,
    required User user,
    required MeRepository meRepo,
  }) {
    return showModalBottomSheet<User>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        // Ensure the sheet lifts above the keyboard when the text field
        // takes focus — otherwise the Save button vanishes below the IME.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: EditProfileSheet(user: user, meRepo: meRepo),
      ),
    );
  }

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.user.displayName);

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Defensive: the button's disabled state already guards this, but
    // another tap during an inflight request would double-submit.
    if (_saving) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final newName = _nameCtrl.text.trim();
    if (newName == widget.user.displayName) {
      // No-op save — dismiss without hitting the network.
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await widget.meRepo.patchMe(displayName: newName);
      // Late-arriving guard: if the sheet was unmounted while the
      // request was in flight, don't touch state or pop navigation.
      if (!mounted) return;
      // Dispatch the refreshed user to the AuthBloc so cached state
      // reflects the rename everywhere.
      context.read<AuthBloc>().add(UserUpdated(updated));
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle — M3 convention for bottom sheets.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Edit profile',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('editProfile.displayName'),
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                maxLength: 80,
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Display name is required';
                  if (v.length > 80) return 'Keep it under 80 characters';
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  key: const Key('editProfile.error'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('editProfile.cancel'),
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('editProfile.save'),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
