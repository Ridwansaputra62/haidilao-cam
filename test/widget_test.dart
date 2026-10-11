import 'package:flutter_test/flutter_test.dart';
import 'package:haidilao_cam/main.dart';

void main() {
  testWidgets('Haidilao Camera App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const HaidilaoCameraApp());
    expect(find.byType(HaidilaoCameraApp), findsOneWidget);
  });
}
