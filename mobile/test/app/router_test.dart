import 'package:flutter_test/flutter_test.dart';
import 'package:surgreference/app/router.dart';
import 'package:surgreference/app/routes.dart';
import 'package:surgreference/features/auth/application/auth_controller.dart';
import 'package:surgreference/features/auth/data/models.dart';

import '../fake_backend.dart';

void main() {
  final user = User.fromJson(userJson());

  test('restoring session always shows the splash', () {
    expect(authRedirect(const AuthRestoring(), Routes.home), Routes.splash);
    expect(authRedirect(const AuthRestoring(), Routes.splash), isNull);
  });

  test('signed out users reach only public screens', () {
    for (final route in Routes.public) {
      expect(authRedirect(const SignedOut(), route), isNull, reason: route);
    }
    for (final route in [Routes.home, Routes.profile, Routes.sessions, '/quiz/appendicitis', Routes.splash]) {
      expect(authRedirect(const SignedOut(), route), Routes.welcome, reason: route);
    }
  });

  test('unverified email is held on the code screen', () {
    expect(authRedirect(const AwaitingVerification('a@example.org'), Routes.home), Routes.verify);
    expect(authRedirect(const AwaitingVerification('a@example.org'), Routes.verify), isNull);
  });

  test('signed in users skip auth screens and keep deep links', () {
    for (final route in [...Routes.public, Routes.splash, Routes.verify]) {
      expect(authRedirect(SignedIn(user), route), Routes.home, reason: route);
    }
    expect(authRedirect(SignedIn(user), '/lesson/appendicitis-diagnosis'), isNull);
  });
}
