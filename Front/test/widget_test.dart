import 'package:flutter_test/flutter_test.dart';
import 'package:tcc_gen_app/app.dart';

void main() {
  testWidgets('GenApp renderiza a árvore raiz', (WidgetTester tester) async {
    await tester.pumpWidget(const GenApp());
    expect(find.byType(GenApp), findsOneWidget);
  });
}
