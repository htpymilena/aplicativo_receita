import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_receitas/view/theme/cores.dart';
import 'package:app_receitas/view/theme/tema.dart';

void main() {
  group('3.1 Testes de Tema e Tokens Visuais', () {
    testWidgets('ThemeData aplica cores corretas e texto escuro ink no botão primário', (tester) async {
      final tema = TemaApp.tema;

      expect(tema.scaffoldBackgroundColor, equals(CoresApp.bg));
      expect(tema.colorScheme.primary, equals(CoresApp.orange500));
      expect(tema.colorScheme.onPrimary, equals(CoresApp.ink));
      expect(tema.colorScheme.surface, equals(CoresApp.surface));
      expect(tema.colorScheme.onSurface, equals(CoresApp.ink));

      final btnTheme = tema.elevatedButtonTheme.style;
      expect(btnTheme, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: tema,
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Ação Primária'),
              ),
            ),
          ),
        ),
      );

      final elevatedBtnFinder = find.widgetWithText(ElevatedButton, 'Ação Primária');
      expect(elevatedBtnFinder, findsOneWidget);
    });
  });
}
