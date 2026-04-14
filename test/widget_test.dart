import 'package:flutter_test/flutter_test.dart';
import 'package:noctua/config/config_service.dart';
import 'package:noctua/main.dart';

void main() {
  testWidgets('app renders without crashing', (WidgetTester tester) async {
    final config_service = ConfigService();
    await tester.pumpWidget(NoctuaApp(config_service: config_service));
    expect(find.byType(NoctuaApp), findsOneWidget);
  });
}
