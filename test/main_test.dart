import 'package:flutter_test/flutter_test.dart';

int suma(int a, int b) {
  return a + b;
}

void main() {
  test('Suma de dos números positivos', () {
    final a = 2;
    final b = 3;
    final resultado = suma(a, b);
    expect(resultado, 5);
  });

  test('Suma de un número y cero', () {
    expect(suma(7, 0), 7);
  });

  test('Suma de dos números negativos', () {
    expect(suma(-5, -10), -15);
  });
}