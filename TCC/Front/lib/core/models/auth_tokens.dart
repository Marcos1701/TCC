class AuthTokens {
  const AuthTokens({required this.access, required this.refresh});

  final String access;
  final String refresh;

  factory AuthTokens.fromMap(Map<String, dynamic> map) {
    final access = map['access'];
    final refresh = map['refresh'];
    
    if (access == null || access is! String) {
      throw const FormatException('Token de acesso inválido ou ausente');
    }
    if (refresh == null || refresh is! String) {
      throw const FormatException('Token de refresh inválido ou ausente');
    }
    
    return AuthTokens(
      access: access,
      refresh: refresh,
    );
  }
}
