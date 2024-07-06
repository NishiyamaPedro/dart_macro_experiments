import 'package:flutter_test/flutter_test.dart';

import 'package:macro_data_class/macro_data_class.dart';

void main() {
  group('Test macro', () {
    test('get values', () {
      final macroTest = MacroTest('test', 50);

      expect(macroTest.get('name'), 'test');
      expect(macroTest.get('age'), 50);
    });

    test('set values', () {
      final macroTest = MacroTest('test', 50);

      macroTest.set('name', 'macro');
      macroTest.set('age', 100);

      expect(macroTest.get('name'), 'macro');
      expect(macroTest.get('age'), 100);
    });

    test('getter/setter', () {
      final macroTest = MacroTest('test', 50);

      macroTest.set('ageMultiply', 2);

      expect(macroTest.get('nameAge'), 'test is 100');
    });
  });
}

@DataClassMacro()
class MacroTest {
  String name;
  int age;

  String get nameAge => '$name is $age';
  set ageMultiply(int value) => age *= value;

  MacroTest(this.name, this.age);
}
