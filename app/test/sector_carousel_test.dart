import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medidor_humedad/widgets/dashboard_charts.dart';

void main() {
  const slides = <SectorSlide>[
    SectorSlide(
      name: 'Sector 1',
      variety: 'Manzano Gala',
      fieldName: 'Campo Norte',
      cropName: 'Manzano',
      humidity: 12.3,
      tempLabel: '22.5°C',
      rangeIdx: 0,
      statusText: 'Requiere riego',
      statusColor: Color(0xFFEF4444),
    ),
    SectorSlide(
      name: 'Sector 2 - variedad bastante larga',
      variety: 'Kiwi Hayward',
      fieldName: 'Campo Sur',
      cropName: 'Kiwi',
      humidity: 55.0,
      tempLabel: '18.2°C',
      rangeIdx: 2,
      statusText: 'OK',
      statusColor: Color(0xFF22C55E),
    ),
    SectorSlide(
      name: 'Sector 3',
      variety: 'Manzano Fuji',
      humidity: double.nan,
      tempLabel: null,
      rangeIdx: -1,
      statusText: 'Sin lecturas',
      statusColor: Color(0xFFFB923C),
    ),
  ];

  testWidgets('SectorCarousel builds sin excepciones y desliza',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: SectorCarousel(slides: slides),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sector 1'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-320, 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sector 2 - variedad bastante larga'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-320, 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sector 3'), findsOneWidget);
  });

  testWidgets('SectorCarousel muestra tarjeta de añadir y dispara callback',
      (WidgetTester tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: SectorCarousel(
                slides: slides,
                onAdd: () => tapped++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Deslizar hasta la última página (tarjeta de añadir).
    for (int i = 0; i < slides.length; i++) {
      await tester.drag(find.byType(PageView), const Offset(-320, 0));
      await tester.pumpAndSettle();
    }
    expect(find.text('Añadir sector'), findsOneWidget);

    await tester.tap(find.text('Añadir sector'));
    await tester.pumpAndSettle();

    expect(tapped, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SectorCarousel muestra botón de eliminar y dispara callback',
      (WidgetTester tester) async {
    var deleted = 0;
    final delSlides = [
      SectorSlide(
        name: 'Sector 1',
        variety: 'Manzano',
        rangeIdx: 0,
        statusText: 'OK',
        statusColor: const Color(0xFF22C55E),
        onDelete: () => deleted++,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: SectorCarousel(slides: delSlides),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(deleted, 1);
    expect(tester.takeException(), isNull);
  });
}
