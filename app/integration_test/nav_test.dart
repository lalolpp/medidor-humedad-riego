import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medidor_humedad/main.dart' as app;

Future<void> waitFor(WidgetTester tester, Finder finder,
    {Duration timeout = const Duration(seconds: 45)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 500));
    if (finder.evaluate().isNotEmpty) return;
  }
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .toList();
  fail('No se encontró: $finder\nTextos en pantalla:\n${texts.join('\n')}');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('flujo demo: abrir detalle de sonda', (tester) async {
    app.main();
    await waitFor(tester, find.byWidgetPredicate((w) {
      if (w is! Text) return false;
      return w.data == 'Continuar como demo' || w.data == 'Mis Dispositivos';
    }));

    if (find.text('Continuar como demo').evaluate().isNotEmpty) {
      await tester.tap(find.text('Continuar como demo'));
      await waitFor(tester, find.text('Mis Dispositivos'));
    }

    final demoCard = find.text('Medidor Humedad Demo');
    await waitFor(tester, demoCard);
    await tester.tap(demoCard.first);
    await waitFor(tester, find.text('Vincular a mi cuenta'));
    expect(find.text('Vincular a mi cuenta'), findsOneWidget);
  });
}
