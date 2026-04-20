import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiksha_setu_2/main.dart';

void main() {
  testWidgets('ShikshaSetu smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ShikshaSetu()));
    await tester.pump();
    // App starts without crashing
  });
}
