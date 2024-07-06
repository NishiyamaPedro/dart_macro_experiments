Experimenting with dart macros. 

Refer to https://dart.dev/language/macros.

## Features

This macro will generate a generic get/set for the class with all the fields and getter/setter.

## Example

```dart
@DataClassMacro()
class MacroTest {
  final int id; // final fields are not included in the setter
  String name;
  int age;

  String get nameAge => '$name is $age';
  set ageMultiply(int value) => age *= value;

  MacroTest(this.id, this.name, this.age);
}

void main() {
  final macroTest = MacroTest(1, 'test', 50);
  macroTest.set('ageMultiply', 2);
  final age = macroTest.get('age'); // age = 100;
}
```