import '../models/dashboard.dart';
import '../network/endpoints.dart';
import '../services/cache_service.dart';
import '../errors/failures.dart';
import 'base_repository.dart';

/// Repositório para operações do dashboard.
class DashboardRepository extends BaseRepository {
  DashboardRepository({super.client});

  Future<DashboardData> fetchDashboard() async {
    try {
      final cached = CacheService.getCachedDashboard();
      if (cached != null) {
        return DashboardData.fromMap(cached);
      }
      
      final response = await client.client.get<Map<String, dynamic>>(
        ApiEndpoints.dashboard,
      );
      final data = response.data ?? <String, dynamic>{};
      
      await CacheService.cacheDashboard(data);
      return DashboardData.fromMap(data);
    } catch (e) {
      if (e is Failure) rethrow;
      throw handleError(e);
    }
  }
}
