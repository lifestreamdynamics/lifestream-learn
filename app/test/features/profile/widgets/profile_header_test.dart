import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifestream_learn_app/data/models/user.dart';
import 'package:lifestream_learn_app/data/repositories/me_repository.dart';
import 'package:lifestream_learn_app/features/profile/widgets/avatar_bytes_cache.dart';
import 'package:lifestream_learn_app/features/profile/widgets/profile_header.dart';
import 'package:mocktail/mocktail.dart';

class _MockMeRepo extends Mock implements MeRepository {}

User _user({
  String displayName = 'Jane Doe',
  String? avatarKey,
  bool useGravatar = false,
}) =>
    User(
      id: 'u1',
      email: 'jane@example.local',
      displayName: displayName,
      role: UserRole.learner,
      createdAt: DateTime.utc(2026, 4, 1),
      avatarKey: avatarKey,
      useGravatar: useGravatar,
    );

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

// A 1-px transparent PNG — smallest valid image a CircleAvatar will
// accept for MemoryImage. We use it to prove the uploaded branch
// actually passes bytes through to the image widget.
final Uint8List _onePxPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
  0x0a, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
]);

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  testWidgets('initials-only when avatarKey is null and Gravatar is off',
      (tester) async {
    await tester.pumpWidget(_wrap(ProfileHeader(user: _user())));
    await tester.pump();

    expect(find.byKey(const Key('profile.avatar')), findsOneWidget);
    // No network image; just the initials text inside the CircleAvatar.
    expect(find.text('JD'), findsOneWidget);
  });

  testWidgets(
      'when avatarKey is set, fetchMyAvatar is called and bytes are rendered',
      (tester) async {
    final repo = _MockMeRepo();
    when(() => repo.fetchMyAvatar()).thenAnswer((_) async => _onePxPng);
    final cache = AvatarBytesCache();

    await tester.pumpWidget(
      _wrap(ProfileHeader(
        user: _user(avatarKey: 'avatars/u1/abc.png'),
        meRepo: repo,
        avatarCache: cache,
      )),
    );
    // Resolve the future.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    verify(() => repo.fetchMyAvatar()).called(1);

    // Find the CircleAvatar with a MemoryImage — proof the bytes took
    // the uploaded branch instead of falling through to initials.
    final avatar =
        tester.widget<CircleAvatar>(find.byKey(const Key('profile.avatar')));
    expect(avatar.foregroundImage, isA<MemoryImage>());
  });

  testWidgets(
      'when fetchMyAvatar returns null, falls through to initials rather than breaking',
      (tester) async {
    final repo = _MockMeRepo();
    when(() => repo.fetchMyAvatar()).thenAnswer((_) async => null);
    final cache = AvatarBytesCache();

    await tester.pumpWidget(
      _wrap(ProfileHeader(
        user: _user(avatarKey: 'avatars/u1/abc.png'),
        meRepo: repo,
        avatarCache: cache,
      )),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    verify(() => repo.fetchMyAvatar()).called(1);

    // Null bytes → fallback circle (initials). No MemoryImage.
    final avatar =
        tester.widget<CircleAvatar>(find.byKey(const Key('profile.avatar')));
    expect(avatar.foregroundImage, isNull);
    expect(find.text('JD'), findsOneWidget);
  });
}
