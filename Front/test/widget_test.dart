import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcc_gen_app/app.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:tcc_gen_app/core/repositories/auth_repository.dart';
import 'package:tcc_gen_app/core/models/session_data.dart';
import 'package:tcc_gen_app/core/models/auth_tokens.dart';
import 'package:tcc_gen_app/core/models/profile.dart';

class FakeAuthRepository extends Fake implements AuthRepository {
  @override
  Future<SessionData> fetchSession() async {
    throw Exception('Session not found');
  }
}

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return '.';
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterSecureStorage.setMockInitialValues({});
    PathProviderPlatform.instance = MockPathProviderPlatform();
    
    // Initialize Hive for testing
    await Hive.initFlutter();
    // Open boxes used in CacheService
    await Hive.openBox('categories_cache');
    await Hive.openBox('missions_cache');
    await Hive.openBox('dashboard_cache');
  });

  testWidgets('GenApp renderiza a árvore raiz', (WidgetTester tester) async {
    await tester.pumpWidget(GenApp(
      theme: ThemeData(),
      darkTheme: ThemeData(),
      authRepository: FakeAuthRepository(),
    ));
    expect(find.byType(GenApp), findsOneWidget);
  });
}
