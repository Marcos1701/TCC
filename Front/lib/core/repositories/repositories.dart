/// Barrel file for all repository exports.
///
/// This file provides a single import point for all repositories.
/// Usage: import 'package:front/core/repositories/repositories.dart';
///
/// ## Repository Structure
///
/// The repositories are organized by domain responsibility:
/// - [AuthRepository] - Authentication and token management
/// - [DashboardRepository] - Dashboard summary data
/// - [CategoryRepository] - Category CRUD operations
/// - [TransactionRepository] - Transaction and links operations
/// - [MissionRepository] - Mission progress and templates
/// - [GoalRepository] - Goal management and insights
/// - [UserRepository] - User profile and account
/// - [DevRepository] - Development-only utilities
///
/// ## Legacy Support
///
/// [FinanceRepository] is maintained for backward compatibility.
/// New code should use the specific repositories above.

// Base repository with common functionality
export 'base_repository.dart';

// Authentication repository
export 'auth_repository.dart';

// Domain-specific repositories (recommended for new code)
export 'category_repository.dart';
export 'dashboard_repository.dart';
export 'goal_repository.dart';
export 'mission_repository.dart';
export 'transaction_repository.dart';
export 'user_repository.dart';

// Development-only repository
export 'dev_repository.dart';

// Legacy repository (maintained for backward compatibility)
export 'finance_repository.dart';
