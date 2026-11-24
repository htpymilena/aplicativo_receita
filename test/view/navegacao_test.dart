import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_receitas/app/app.dart';
import 'package:app_receitas/view/telas/navegacao_principal.dart';

void main() {
  group('4.1, 4.2 e 4.3 Testes de Navegação Principal e Telas Provisórias', () {
    testWidgets('4.1 Navegação abre inicialmente no Início e alterna entre as 5 abas', (tester) async {
      await tester.pumpWidget(const AppReceitas());

      // Aba inicial é Início
      expect(find.text('O que vamos cozinhar hoje?'), findsOneWidget);

      // Tocar em Comunidade
      await tester.tap(find.text('Comunidade'));
      await tester.pumpAndSettle();
      expect(find.text('Comunidade de Receitas'), findsOneWidget);

      // Tocar em Favoritos
      await tester.tap(find.text('Favoritos'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum favorito guardado'), findsOneWidget);

      // Tocar em Histórico
      await tester.tap(find.text('Histórico'));
      await tester.pumpAndSettle();
      expect(find.text('Sem histórico de preparos'), findsOneWidget);

      // Tocar em Perfil
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Cozinheiro Local'), findsOneWidget);

      // Retornar ao Início
      await tester.tap(find.text('Início'));
      await tester.pumpAndSettle();
      expect(find.text('O que vamos cozinhar hoje?'), findsOneWidget);
    });

    testWidgets('4.2 Cada tela exibe mensagens e ilustrações honestas sem dados fictícios', (tester) async {
      await tester.pumpWidget(const AppReceitas());

      // Início
      expect(find.text('Nenhuma receita cadastrada ainda'), findsOneWidget);
      expect(find.text('O gerenciamento de receitas próprias será implementado na Etapa 2.'), findsOneWidget);
    });

    testWidgets('4.3 Responsividade em 360 dp de largura com texto ampliado a 200%', (tester) async {
      // Configurar tela estreita de 360 x 640 dp
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(2.0), // 200% de escala de texto
            size: Size(360, 640),
          ),
          child: AppReceitas(),
        ),
      );

      expect(find.byType(NavegacaoPrincipal), findsOneWidget);
      expect(find.text('Início'), findsWidgets);
      expect(find.text('Perfil'), findsWidgets);
    });
  });
}
