import 'package:flutter_test/flutter_test.dart';
import 'package:road_anomaly_collector/main.dart';

void main() {
  testWidgets('App renders successfully smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}
