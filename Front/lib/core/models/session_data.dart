import 'profile.dart';

class SessionData {
  const SessionData({required this.user, required this.profile});

  final UserHeader user;
  final ProfileModel profile;
}
