import '../network/api_client.dart';
import '../network/endpoints.dart';
import 'base_repository.dart';

/// Repository for development-only endpoints.
class DevRepository extends BaseRepository {
  /// Creates a [DevRepository] instance.
  ///
  /// Optionally accepts an [ApiClient] for dependency injection.
  DevRepository({super.client});

  /// Resets the current user's account to initial state.
  Future<Map<String, dynamic>> resetAccount() async {
    final response = await client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.user}dev_reset_account/',
    );
    return response.data ?? {};
  }

  /// Adds XP points to the current user.
  Future<Map<String, dynamic>> addXp(int xp) async {
    final response = await client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.user}dev_add_xp/',
      data: {'xp': xp},
    );
    return response.data ?? {};
  }

  /// Marks all active missions as completed.
  Future<Map<String, dynamic>> completeMissions() async {
    final response = await client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.user}dev_complete_missions/',
    );
    return response.data ?? {};
  }

  /// Clears all cached data on the server.
  Future<Map<String, dynamic>> clearCache() async {
    final response = await client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.user}dev_clear_cache/',
    );
    return response.data ?? {};
  }

  /// Adds test data to the account.create.
  Future<Map<String, dynamic>> addTestData(int count) async {
    final response = await client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.user}dev_add_test_data/',
      data: {'count': count},
    );
    return response.data ?? {};
  }
}
