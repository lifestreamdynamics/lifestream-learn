import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/date_formatters.dart';
import '../../../data/models/user.dart';

/// Avatar + identity block for the profile screen.
///
/// Resolution order: user-uploaded avatar (deferred until the media-serving
/// route lands — `user.avatarKey` is captured server-side today but there's
/// no URL to fetch it from yet) → Gravatar fallback (opt-in via
/// `user.useGravatar`) → initials-on-colored-circle. The Gravatar URL is
/// built client-side from `sha256(email.trim().toLowerCase())` with
/// `?d=404` so a missing Gravatar falls cleanly through to initials
/// without a render glitch. Per the plan's §D privacy note, Gravatar is
/// an opt-in third-party request keyed on an email hash.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({required this.user, super.key});

  final User user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final memberSince = formatMemberSinceMonthYear(user.createdAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Avatar(
            displayName: user.displayName,
            userId: user.id,
            gravatarUrl: _gravatarUrlFor(user),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  key: const Key('profile.displayName'),
                  style: theme.textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  key: const Key('profile.email'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(
                      key: const Key('profile.role'),
                      label: Text(user.role.label),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    if (memberSince.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Member since $memberSince',
                          key: const Key('profile.memberSince'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-letter initials on a colored circle, optionally overlaid by a
/// Gravatar image when the user has opted in. Initial colour is derived
/// from a stable hash of `userId` so the same user always gets the same
/// colour and bucketing across users is roughly uniform.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.displayName,
    required this.userId,
    this.gravatarUrl,
  });

  final String displayName;
  final String userId;
  final String? gravatarUrl;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    // M3 primary/secondary/tertiary rotation — enough variety to feel
    // individual without introducing off-palette colors.
    final bg = _pickColor(userId, <Color>[
      palette.primary,
      palette.secondary,
      palette.tertiary,
      palette.primaryContainer,
      palette.secondaryContainer,
      palette.tertiaryContainer,
    ]);
    final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black;

    final initials = Text(
      _initials(displayName),
      style: TextStyle(
        color: fg,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    );

    // TODO(follow-up): when the media-serving route lands for uploaded
    // avatars, try `user.avatarKey`-derived URL first, fall through to
    // Gravatar, then initials. Today we go straight to the Gravatar
    // branch when opted in — no upload serving exists yet.
    final CircleAvatar circle;
    if (gravatarUrl != null) {
      circle = CircleAvatar(
        key: const Key('profile.avatar'),
        radius: 32,
        backgroundColor: bg,
        foregroundImage: NetworkImage(gravatarUrl!),
        // Rendered behind the image; shown if the network load fails
        // (d=404 on Gravatar) so initials stay as the hard fallback.
        child: initials,
      );
    } else {
      circle = CircleAvatar(
        key: const Key('profile.avatar'),
        radius: 32,
        backgroundColor: bg,
        child: initials,
      );
    }

    return Semantics(
      label: 'Avatar for $displayName',
      child: circle,
    );
  }

  static String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  static Color _pickColor(String userId, List<Color> palette) {
    // FNV-1a 32-bit — deterministic, cheap, no crypto needs.
    int hash = 0x811c9dc5;
    for (final code in userId.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return palette[hash % palette.length];
  }
}

/// Build the Gravatar URL for a user if they've opted in. Returns null
/// when the user has `useGravatar == false` or an empty email — the
/// caller renders initials in both cases. `?d=404` means Gravatar
/// returns a 404 (which NetworkImage surfaces as an error, falling
/// through to the CircleAvatar's initials child) rather than a generic
/// silhouette, so we stay in our own colour palette end-to-end.
String? _gravatarUrlFor(User user) {
  if (!user.useGravatar) return null;
  final email = user.email.trim().toLowerCase();
  if (email.isEmpty) return null;
  final hash = sha256.convert(utf8.encode(email)).toString();
  return 'https://www.gravatar.com/avatar/$hash?s=128&d=404';
}
