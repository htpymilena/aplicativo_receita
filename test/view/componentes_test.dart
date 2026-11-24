import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_receitas/view/componentes/componentes.dart';
import 'package:app_receitas/view/theme/tema.dart';

void main() {
  Widget wrap(Widget widget) {
    return MaterialApp(
      theme: TemaApp.tema,
      home: Scaffold(
        body: SingleChildScrollView(child: widget),
      ),
    );
  }

  group('3.2 e 3.3 Testes de Componentes Base', () {
    testWidgets('3.2 BotaoPrimario tem 56 dp de altura e exibe motivo quando desabilitado', (tester) async {
      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              BotaoPrimario(
                texto: 'Iniciar receita',
                onPressed: () {},
              ),
              const BotaoPrimario(
                texto: 'Concluir preparo',
                onPressed: null,
                motivoDesabilitado: 'Faltam etapas para concluir',
              ),
            ],
          ),
        ),
      );

      final btnFinder = find.widgetWithText(ElevatedButton, 'Iniciar receita');
      expect(btnFinder, findsOneWidget);
      final size = tester.getSize(btnFinder);
      expect(size.height, equals(56));

      expect(find.text('Faltam etapas para concluir'), findsOneWidget);
    });

    testWidgets('3.2 BotaoSecundario e BotaoTerciario respeitam alvo mínimo de 48 dp', (tester) async {
      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              BotaoSecundario(
                texto: 'Salvar rascunho',
                onPressed: () {},
              ),
              BotaoTerciario(
                texto: 'Cancelar',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      final secFinder = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
      expect(secFinder, findsOneWidget);
      expect(tester.getSize(secFinder).height, greaterThanOrEqualTo(48));

      final tercFinder = find.widgetWithText(TextButton, 'Cancelar');
      expect(tercFinder, findsOneWidget);
      expect(tester.getSize(tercFinder).height, greaterThanOrEqualTo(48));
    });

    testWidgets('3.2 CampoTextoApp renderiza rótulo e aceita digitação', (tester) async {
      String digitado = '';
      await tester.pumpWidget(
        wrap(
          CampoTextoApp(
            label: 'Nome da receita',
            dica: 'Ex: Panqueca de banana',
            onChanged: (val) => digitado = val,
          ),
        ),
      );

      expect(find.text('Nome da receita'), findsOneWidget);
      expect(find.text('Ex: Panqueca de banana'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Bolo de Cenoura');
      expect(digitado, equals('Bolo de Cenoura'));
    });

    testWidgets('3.3 SeloEstado exibe ícone e texto correspondente sem depender só de cor', (tester) async {
      await tester.pumpWidget(
        wrap(
          const Column(
            children: [
              SeloEstado(tipo: TipoSelo.tenho),
              SeloEstado(tipo: TipoSelo.falta),
              SeloEstado(tipo: TipoSelo.naoConferido),
              SeloEstado(tipo: TipoSelo.publicada),
              SeloEstado(tipo: TipoSelo.privada),
            ],
          ),
        ),
      );

      expect(find.text('Tenho'), findsOneWidget);
      expect(find.text('Falta'), findsOneWidget);
      expect(find.text('Não conferido'), findsOneWidget);
      expect(find.text('Pública'), findsOneWidget);
      expect(find.text('Privada'), findsOneWidget);

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('3.3 CartaoReceita, EstadoVazio e EsqueletoCarregamento exibem conteúdo', (tester) async {
      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              CartaoReceita(
                titulo: 'Panqueca de Aveia',
                categoria: 'Café da Manhã',
                mediaEstrelas: 4.8,
                totalAvaliacoes: 12,
                onTap: () {},
              ),
              const EstadoVazio(
                icone: Icons.inbox,
                titulo: 'Vazio',
                mensagem: 'Nenhum item encontrado',
              ),
              const EsqueletoCarregamento(quantidadeLinhas: 2),
            ],
          ),
        ),
      );

      expect(find.text('Panqueca de Aveia'), findsOneWidget);
      expect(find.text('Café da Manhã'), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text(' (12)'), findsOneWidget);

      expect(find.text('Vazio'), findsOneWidget);
      expect(find.text('Nenhum item encontrado'), findsOneWidget);
      expect(find.byType(EsqueletoCarregamento), findsOneWidget);
    });
  });
}
