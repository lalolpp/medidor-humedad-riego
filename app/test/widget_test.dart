import 'package:flutter_test/flutter_test.dart';

import 'package:medidor_humedad/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MedidorHumedadApp());
    await tester.pump();

    expect(find.text('Mis Dispositivos'), findsOneWidget);
    expect(find.text('Modo demo (sin hardware)'), findsOneWidget);
  });
}
