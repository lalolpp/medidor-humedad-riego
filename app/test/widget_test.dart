import 'package:flutter_test/flutter_test.dart';

import 'package:medidor_humedad/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MedidorHumedadApp());

    expect(find.text('Medidor de Humedad'), findsOneWidget);
    expect(find.text('Continuar como demo'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
