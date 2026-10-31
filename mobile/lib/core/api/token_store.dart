/// Хранилище refresh-токена. Access-токен живёт только в памяти (docs/02-architecture.md, 2.6).
abstract interface class TokenStore {
  Future<String?> readRefresh();
  Future<void> writeRefresh(String token);
  Future<void> clear();
}

class MemoryTokenStore implements TokenStore {
  String? _refresh;

  @override
  Future<String?> readRefresh() async => _refresh;

  @override
  Future<void> writeRefresh(String token) async => _refresh = token;

  @override
  Future<void> clear() async => _refresh = null;
}
