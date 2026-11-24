import 'package:flutter_test/flutter_test.dart';
import 'package:app_receitas/main.dart';
import 'package:app_receitas/view/telas/navegacao_principal.dart';
import 'package:app_receitas/view/telas/tela_erro_banco.dart';

void main() {
  group('2.2 Testes de Ciclo de Vida e Inicialização do Aplicativo', () {
    testWidgets('Inicialização com sucesso abre a tela principal', (tester) async {
      await tester.pumpWidget(
        RaizApp(
          inicializadorBanco: () async {},
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(NavegacaoPrincipal), findsOneWidget);
      expect(find.text('O que vamos cozinhar hoje?'), findsOneWidget);
    });

    testWidgets('Falha na inicialização apresenta tela de erro recuperável com opção tentar novamente', (tester) async {
      int tentativas = 0;

      await tester.pumpWidget(
        RaizApp(
          inicializadorBanco: () async {
            tentativas++;
            if (tentativas == 1) {
              throw Exception('Disco cheio ou bloqueado');
            }
          },
        ),
      );

      await tester.pumpAndSettle();

      // Tela de erro é exibida
      expect(find.byType(TelaErroBanco), findsOneWidget);
      expect(find.text('Falha ao carregar o banco de dados'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);

      // Clicar em tentar novamente
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      // Agora sucesso!
      expect(find.byType(NavegacaoPrincipal), findsOneWidget);
      expect(tentativas, equals(2));
    });
  });
}
