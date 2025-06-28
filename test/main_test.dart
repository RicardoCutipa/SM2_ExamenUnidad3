import 'package:flutter_test/flutter_test.dart';
import 'package:proyectomovilesii/utils/validators.dart';

void main() {
  test('Email válido debe retornar null', () {
    final resultado = Validators.validateEmail('usuarioprueba@gmail.com');
    expect(resultado, isNull);
  });

  test('Contraseña válida debe retornar null', () {
    final resultado = Validators.validatePassword('123456');
    expect(resultado, isNull);
  });

  test('Nombre vacío debe retornar un mensaje de error', () {
    final resultado = Validators.validateName('');
    expect(resultado, 'Por favor, ingresa tu nombre');
  });
}