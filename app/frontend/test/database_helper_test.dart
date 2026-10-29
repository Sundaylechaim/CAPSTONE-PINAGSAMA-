import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinigsenyas/services/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists conversation history in the web SQLite database', () async {
    if (!kIsWeb) return;

    final database = DatabaseHelper.instance;
    await database.clearHistory();
    final id = await database.saveRecognizedGesture(
      'Database smoke test',
      1,
      source: 'test',
    );

    final saved = await database.getConversationById(id);
    expect(saved?.text, 'Database smoke test');
    expect(saved?.source, 'test');

    await database.deleteConversation(id);
  });
}
