import 'package:flutter_test/flutter_test.dart';
import 'package:medidor_humedad/models/automation_config.dart';

void main() {
  group('AutomationConfig.inWindow', () {
    final allDay = const AutomationConfig();
    final day = const AutomationConfig(startMin: 8 * 60, endMin: 20 * 60);
    final overnight = const AutomationConfig(startMin: 22 * 60, endMin: 6 * 60);

    DateTime at(int hour, int minute) => DateTime(2026, 8, 7, hour, minute);

    test('todo el día permite cualquier hora', () {
      expect(allDay.inWindow(at(0, 0)), isTrue);
      expect(allDay.inWindow(at(23, 59)), isTrue);
      expect(allDay.inWindow(at(12, 30)), isTrue);
    });

    test('ventana diurna respeta inicio/fin', () {
      expect(day.inWindow(at(8, 0)), isTrue);
      expect(day.inWindow(at(19, 59)), isTrue);
      expect(day.inWindow(at(20, 0)), isFalse);
      expect(day.inWindow(at(7, 59)), isFalse);
    });

    test('ventana que cruza medianoche', () {
      expect(overnight.inWindow(at(23, 0)), isTrue);
      expect(overnight.inWindow(at(2, 0)), isTrue);
      expect(overnight.inWindow(at(5, 59)), isTrue);
      expect(overnight.inWindow(at(6, 0)), isFalse);
      expect(overnight.inWindow(at(12, 0)), isFalse);
    });
  });
}
