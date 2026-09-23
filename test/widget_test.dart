import 'package:flutter_test/flutter_test.dart';
import 'package:saar/main.dart';

void main() {
  testWidgets('App starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const SaarApp());
    expect(find.text('SAAR'), findsOneWidget);
  });
}
