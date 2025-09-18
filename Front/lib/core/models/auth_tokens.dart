class AuthTokens {
  const AuthTokens({required this.access, required this.refresh});

  final String access;
  final String refresh;

  factory AuthTokens.fromMap(Map<String, dynamic> map) {
    return AuthTokens(
      access: map['access'] as String,
      refresh: map['refresh'] as String,
    );
  }
}
