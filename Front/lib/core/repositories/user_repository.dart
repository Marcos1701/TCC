import '../network/api_client.dart';
import '../network/endpoints.dart';
import 'base_repository.dart';

/// Repository for user profile and account operations.
///
/// Handles user profile retrieval, updates, password changes,
/// account deletion and onboarding flows.
class UserRepository extends BaseRepository {
  /// Creates a [UserRepository] instance.
  ///
  /// Optionally accepts an [ApiClient] for dependency injection.
  UserRepository({super.client});

  // ===========================================================================
  // PROFILE OPERATIONS
  // ===========================================================================

  /// Fetches the current user's profile information.
  Future<Map<String, dynamic>> fetchUserProfile() async {
    final response = await client.client.get<Map<String, dynamic>>(
      '${ApiEndpoints.user}me/',
    );
    return response.data ?? {};
  }

  /// Updates the user's profile information.
  ///
  /// Parameters:
  /// - [name]: New user name
  /// - [email]: New email address
  Future<Map<String, dynamic>> updateUserProfile({
    required String name,
    required String email,
  }) async {
    final response = await client.client.patch<Map<String, dynamic>>(
      '${ApiEndpoints.user}update_profile/',
      data: {
        'name': name,
        'email': email,
      },
    );
    return response.data ?? {};
  }

  // ===========================================================================
  // PASSWORD & ACCOUNT
  // ===========================================================================

  /// Changes the user's password.
  ///
  /// Parameters:
  /// - [currentPassword]: Current password for verification
  /// - [newPassword]: New password to set
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await client.client.post<Map<String, dynamic>>(
      '${ApiEndpoints.user}change_password/',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
    return response.data ?? {};
  }

  /// Deletes the user's account.
  ///
  /// Requires the current password for verification.
  /// This action is irreversible.
  Future<Map<String, dynamic>> deleteAccount({
    required String password,
  }) async {
    final response = await client.client.delete<Map<String, dynamic>>(
      '${ApiEndpoints.user}delete_account/',
      data: {
        'password': password,
      },
    );
    return response.data ?? {};
  }

  // ===========================================================================
  // ONBOARDING & FIRST ACCESS
  // ===========================================================================

  /// Marks the user's first access as completed.
  ///
  /// This updates the backend flag that controls onboarding UI.
  Future<void> completeFirstAccess() async {
    await client.client.patch<Map<String, dynamic>>(
      ApiEndpoints.profile,
      data: {
        'complete_first_access': true,
      },
    );
  }

  /// Completes the simplified onboarding flow.
  ///
  /// Parameters:
  /// - [monthlyIncome]: User's estimated monthly income
  /// - [essentialExpenses]: User's estimated essential monthly expenses
  ///
  /// Returns onboarding completion data including generated initial data.
  Future<Map<String, dynamic>> completeSimplifiedOnboarding({
    required double monthlyIncome,
    required double essentialExpenses,
  }) async {
    final response = await client.client.post<Map<String, dynamic>>(
      ApiEndpoints.simplifiedOnboarding,
      data: {
        'monthly_income': monthlyIncome,
        'essential_expenses': essentialExpenses,
      },
    );
    return response.data ?? {};
  }
}
