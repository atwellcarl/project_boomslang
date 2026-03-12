import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lrm_trainer/main.dart';

void main() {
  testWidgets('Home screen renders LRM title', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: LrmTrainerApp()));
    expect(find.text('LRM'), findsOneWidget);
  });
}
