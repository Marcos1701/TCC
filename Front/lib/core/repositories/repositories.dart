// Barrel file for all repository exports.
//
// This file provides a single import point for all repositories.
// Usage: import 'package:front/core/repositories/repositories.dart';
//
// Repository Structure:
// - AuthRepository - Authentication and token management
// - DashboardRepository - Dashboard summary data
// - CategoryRepository - Category CRUD operations
// - TransactionRepository - Transaction and links operations
// - MissionRepository - Mission progress and templates
// - FinanceRepository - Legacy repository with user profile/account methods
//
// Note: User profile and dev methods are available via FinanceRepository.

// Base repository with common functionality
export 'base_repository.dart';

// Authentication repository
export 'auth_repository.dart';

// Domain-specific repositories (recommended for new code)
export 'category_repository.dart';
export 'dashboard_repository.dart';
export 'mission_repository.dart';
export 'transaction_repository.dart';

// Legacy repository (maintained for backward compatibility)
// Also contains user profile, password, and dev methods
export 'finance_repository.dart';
