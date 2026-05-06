import 'package:flutter_test/flutter_test.dart';
import 'package:internet_verify/main.dart';

void main() {
  testWidgets('App starts smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DataVerifyApp());

    expect(find.text('Verifyte'), findsNothing);
  });
}
