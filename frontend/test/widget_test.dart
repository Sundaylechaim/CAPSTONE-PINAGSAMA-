import 'package:flutter_test/flutter_test.dart';
import 'package:tinigsenyas/main.dart'; 

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TinigSenyasApp());

    // Verify that the app loads successfully by looking for your title
    expect(find.text('TinigSenyas'), findsWidgets);
  });
}