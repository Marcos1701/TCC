import '../models/category.dart';
import '../network/endpoints.dart';
import '../services/cache_service.dart';
import '../errors/failures.dart';
import 'base_repository.dart';

class CategoryRepository extends BaseRepository {
  CategoryRepository({super.client});

  Future<List<CategoryModel>> fetchCategories({String? type}) async {
    try {
      if (type == null) {
        final cached = CacheService.getCachedCategories();
        if (cached != null) {
          return cached.map((e) => CategoryModel.fromMap(e)).toList();
        }
      }
      
      final response = await client.client.get<dynamic>(
        ApiEndpoints.categories,
        queryParameters: type != null ? {'type': type} : null,
      );
      final items = extractListFromResponse(response.data);
      final categories = items
          .map((e) => CategoryModel.fromMap(e as Map<String, dynamic>))
          .toList();
      
      if (type == null) {
        await CacheService.cacheCategories(
          categories.map((c) => c.toMap()).toList(),
        );
      }
      
      return categories;
    } catch (e) {
      if (e is Failure) rethrow;
      throw handleError(e);
    }
  }

  Future<CategoryModel> createCategory({
    required String name,
    required String type,
    String? color,
    String? group,
  }) async {
    final payload = {
      'name': name,
      'type': type,
      if (color != null) 'color': color,
      if (group != null) 'group': group,
    };
    final response = await client.client.post<Map<String, dynamic>>(
      ApiEndpoints.categories,
      data: payload,
    );
    await CacheService.invalidateCategories();
    return CategoryModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<CategoryModel> updateCategory({
    required String id,
    required String name,
    required String type,
    String? color,
    String? group,
  }) async {
    final payload = {
      'name': name,
      'type': type,
      if (color != null) 'color': color,
      if (group != null) 'group': group,
    };
    final response = await client.client.put<Map<String, dynamic>>(
      '${ApiEndpoints.categories}$id/',
      data: payload,
    );
    await CacheService.invalidateCategories();
    return CategoryModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<void> deleteCategory(String id) async {
    try {
      await client.client.delete('${ApiEndpoints.categories}$id/');
      await CacheService.invalidateCategories();
    } catch (e) {
      throw handleError(e);
    }
  }
}
