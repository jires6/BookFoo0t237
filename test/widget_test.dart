import 'package:flutter_test/flutter_test.dart';

import 'package:bookfoot237/core/app.dart';

void main() {
  testWidgets('BookFoot237 smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BookFootApp());

    // Verify that our app shows the login page
    expect(find.text('BookFoot237'), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Entrer comme Client'), findsOneWidget);
    expect(find.text('Entrer comme Gestionnaire'), findsOneWidget);
  });
}