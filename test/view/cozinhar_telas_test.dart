import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_receitas/controller/controller_historico.dart';
import 'package:app_receitas/controller/controller_preparo.dart';
import 'package:app_receitas/controller/controller_receitas.dart';
import 'package:app_receitas/model/entidades/entidades.dart';
import 'package:app_receitas/model/repositorios/repositorio_preparos.dart';
import 'package:app_receitas/model/repositorios/repositorio_receitas.dart';
import 'package:app_receitas/view/telas/checklist_preparo_tela.dart';
import 'package:app_receitas/view/telas/conclusao_preparo_tela.dart';
import 'package:app_receitas/view/telas/detalhe_preparo_tela.dart';
import 'package:app_receitas/view/telas/etapas_preparo_tela.dart';
import 'package:app_receitas/view/telas/ficha_receita_tela.dart';
import 'package:app_receitas/view/telas/historico_tela.dart';
import 'package:app_receitas/view/telas/inicio_tela.dart';
import 'package:app_receitas/view/telas/navegacao_principal.dart';
import 'package:app_receitas/view/theme/tema.dart';

void main() {
  Widget wrap(Widget child, {double textScaleFactor = 1.0, Size size = const Size(800, 1000)}) {
    return MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScaleFactor),
      ),
      child: MaterialApp(
        theme: TemaApp.tema,
        home: child,
      ),
    );
  }

  PreparoDetalhado criarPreparoMock({int etapaAtual = 1, bool concluido = false, int? estrelas}) {
    final agora = DateTime.now().toUtc();
    return PreparoDetalhado(
      preparo: Preparo(
        idPreparo: 'prep_mock_1',
        idUsuario: 'user_1',
        idVersao: 'versao_1',
        iniciadoEm: agora,
        concluidoEm: concluido ? agora : null,
        ordemEtapaAtual: etapaAtual,
      ),
      versao: const VersaoReceita(
        idVersao: 'versao_1',
        idReceita: 'rec_1',
        numeroVersao: 1,
        titulo: 'Torta de Maçã',
        categoria: 'Sobremesa',
      ),
      receita: const Receita(
        idReceita: 'rec_1',
        idAutor: 'user_1',
        origem: 'usuario',
        visibilidade: 'privada',
        estadoModeracao: 'liberada',
      ),
      conferencias: const [
        ConferenciaItem(
          idItem: 'item_1',
          idIngrediente: 'ing_1',
          nomeIngrediente: 'Maçã',
          medida: '3 unidades',
          ordem: 1,
          estado: 'nao_conferido',
        ),
        ConferenciaItem(
          idItem: 'item_2',
          idIngrediente: 'ing_2',
          nomeIngrediente: 'Canela',
          medida: '1 colher de chá',
          ordem: 2,
          estado: 'nao_conferido',
        ),
      ],
      etapas: const [
        Etapa(idEtapa: 'etapa_1', idVersao: 'versao_1', ordem: 1, instrucao: 'Pique as maçãs em fatias finas.'),
        Etapa(idEtapa: 'etapa_2', idVersao: 'versao_1', ordem: 2, instrucao: 'Polvilhe a canela e asse por 30 minutos.'),
      ],
      avaliacao: estrelas != null
          ? Avaliacao(
              idPreparo: 'prep_mock_1',
              estrelas: estrelas,
              visibilidade: 'privada',
              estadoModeracao: 'liberada',
              avaliadaEm: agora,
            )
          : null,
    );
  }

  group('2.2 a 2.4, 3.2 a 3.4, 4.2 e 5.4 Testes de Interface e Fluxo de Cozinha', () {
    testWidgets('2.2 Ficha da receita possui botão Iniciar receita e abre Checklist', (tester) async {
      final ctrlReceitas = ControllerReceitas();
      final ctrlPreparo = ControllerPreparo(repositorio: RepositorioPreparos(forcarMemoria: true));

      ctrlReceitas.receitaSelecionada = ReceitaCompleta(
        receita: const Receita(
          idReceita: 'rec_1',
          idAutor: 'user_1',
          origem: 'usuario',
          visibilidade: 'privada',
          estadoModeracao: 'liberada',
        ),
        versao: const VersaoReceita(
          idVersao: 'versao_1',
          idReceita: 'rec_1',
          numeroVersao: 1,
          titulo: 'Bolo Caseiro',
          categoria: 'Bolos',
        ),
        itens: const [
          ItemReceitaDetalhado(
            idItem: 'item_1',
            idIngrediente: 'ing_1',
            nomeIngrediente: 'Farinha',
            ordem: 1,
            medida: '2 xícaras',
          ),
        ],
        etapas: const [
          Etapa(idEtapa: 'etapa_1', idVersao: 'versao_1', ordem: 1, instrucao: 'Misture tudo e asse.'),
        ],
      );

      await tester.pumpWidget(
        wrap(FichaReceitaTela(
          idReceita: 'rec_1',
          controller: ctrlReceitas,
          controllerPreparo: ctrlPreparo,
        )),
      );
      await tester.pumpAndSettle();

      expect(find.text('Iniciar receita'), findsOneWidget);
      await tester.ensureVisible(find.text('Iniciar receita'));
      await tester.tap(find.text('Iniciar receita'));
      await tester.pumpAndSettle();

      expect(find.byType(ChecklistPreparoTela), findsOneWidget);
    });

    testWidgets('2.2 Checklist exibe 3 estados, contador, aviso de falta e avanço livre', (tester) async {
      final ctrlPreparo = ControllerPreparo(repositorio: RepositorioPreparos(forcarMemoria: true));
      ctrlPreparo.preparoAtual = criarPreparoMock();

      await tester.pumpWidget(wrap(ChecklistPreparoTela(controller: ctrlPreparo)));
      await tester.pumpAndSettle();

      expect(find.text('0 de 2 conferidos'), findsOneWidget);
      expect(find.text('Seguir para as etapas'), findsOneWidget);

      // Marca o primeiro como Tenho
      await tester.tap(find.text('Tenho').first);
      await tester.pumpAndSettle();
      expect(find.text('1 de 2 conferidos'), findsOneWidget);
      expect(find.text('1 tenho · 0 falta'), findsOneWidget);

      // Marca o segundo como Falta
      await tester.tap(find.text('Falta').last);
      await tester.pumpAndSettle();
      expect(find.text('2 de 2 conferidos'), findsOneWidget);
      expect(find.text('1 tenho · 1 falta'), findsOneWidget);

      // Aviso de faltantes deve estar visível
      expect(find.textContaining('você marcou 1 ingrediente(s) como falta'), findsOneWidget);

      // Avanço não é bloqueado
      await tester.tap(find.text('Seguir para as etapas'));
      await tester.pumpAndSettle();
      expect(find.byType(EtapasPreparoTela), findsOneWidget);
    });

    testWidgets('2.3 Etapas mostra 1 instrução por vez, navegação e diálogo de confirmação', (tester) async {
      final ctrlPreparo = ControllerPreparo(repositorio: RepositorioPreparos(forcarMemoria: true));
      ctrlPreparo.preparoAtual = criarPreparoMock(etapaAtual: 1);

      await tester.pumpWidget(wrap(EtapasPreparoTela(controller: ctrlPreparo)));
      await tester.pumpAndSettle();

      expect(find.text('Etapa 1 de 2'), findsOneWidget);
      expect(find.text('Pique as maçãs em fatias finas.'), findsOneWidget);
      expect(find.text('Próxima'), findsOneWidget);

      // Avança para etapa 2
      await tester.tap(find.text('Próxima'));
      await tester.pumpAndSettle();

      expect(find.text('Etapa 2 de 2'), findsOneWidget);
      expect(find.text('Polvilhe a canela e asse por 30 minutos.'), findsOneWidget);
      expect(find.text('Anterior'), findsOneWidget);
      expect(find.text('Concluir preparo'), findsOneWidget);

      // Clica em Concluir preparo -> abre diálogo
      await tester.tap(find.text('Concluir preparo'));
      await tester.pumpAndSettle();
      expect(find.text('Concluir preparo?'), findsOneWidget);

      // Cancela no diálogo
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Concluir preparo?'), findsNothing);
      expect(ctrlPreparo.preparoAtual?.preparo.concluidoEm, isNull);

      // Abre diálogo novamente e confirma
      await tester.tap(find.text('Concluir preparo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();

      expect(find.byType(ConclusaoPreparoTela), findsOneWidget);
    });

    testWidgets('2.4 Conclusão exibe nota opcional e Pular avaliação sem opção pública', (tester) async {
      final ctrlPreparo = ControllerPreparo(repositorio: RepositorioPreparos(forcarMemoria: true));
      ctrlPreparo.preparoAtual = criarPreparoMock(etapaAtual: 2, concluido: true);

      await tester.pumpWidget(wrap(ConclusaoPreparoTela(controller: ctrlPreparo)));
      await tester.pumpAndSettle();

      expect(find.text('Parabéns!'), findsOneWidget);
      expect(find.text('Como ficou o seu prato?'), findsOneWidget);
      expect(find.text('Privada'), findsOneWidget); // Selo de visibilidade privada
      expect(find.text('Pública'), findsNothing); // Sem opção pública nesta etapa
      expect(find.text('Pular avaliação'), findsOneWidget);

      // Seleciona 4 estrelas
      final estrelas = find.byIcon(Icons.star_outline_rounded);
      expect(estrelas, findsNWidgets(5));
      await tester.tap(estrelas.at(3));
      await tester.pumpAndSettle();

      expect(find.text('Salvar avaliação'), findsOneWidget);
    });

    testWidgets('3.2 Histórico exibe lista de concluídos, selo Receita indisponível e abre detalhe', (tester) async {
      final ctrlHistorico = ControllerHistorico(repositorio: RepositorioPreparos(forcarMemoria: true));
      final agora = DateTime.now().toUtc();

      ctrlHistorico.concluidos = [
        PreparoResumo(
          idPreparo: 'prep_concluido_1',
          idReceita: 'rec_1',
          idVersao: 'versao_1',
          tituloReceita: 'Lasanha à Bolonhesa',
          iniciadoEm: agora.subtract(const Duration(hours: 2)),
          concluidoEm: agora,
          ordemEtapaAtual: 3,
          totalEtapas: 3,
          estrelas: 5,
          receitaExcluida: true,
        ),
      ];

      await tester.pumpWidget(wrap(HistoricoTela(controller: ctrlHistorico)));
      await tester.pumpAndSettle();

      expect(find.text('Lasanha à Bolonhesa'), findsOneWidget);
      expect(find.text('Receita indisponível'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // Mocka detalhe para clique
      ctrlHistorico.detalhePreparo = criarPreparoMock(etapaAtual: 2, concluido: true, estrelas: 5);
      await tester.tap(find.text('Lasanha à Bolonhesa'));
      await tester.pumpAndSettle();

      expect(find.byType(DetalhePreparoTela), findsOneWidget);
    });

    testWidgets('3.3 Início exibe Continue de onde parou e Feitas recentemente', (tester) async {
      final ctrlHistorico = ControllerHistorico(repositorio: RepositorioPreparos(forcarMemoria: true));
      final ctrlPreparo = ControllerPreparo(repositorio: RepositorioPreparos(forcarMemoria: true));
      final agora = DateTime.now().toUtc();

      ctrlHistorico.emAndamento = [
        PreparoResumo(
          idPreparo: 'prep_andamento_1',
          idReceita: 'rec_2',
          idVersao: 'versao_2',
          tituloReceita: 'Risoto de Cogumelos',
          iniciadoEm: agora,
          concluidoEm: null,
          ordemEtapaAtual: 2,
          totalEtapas: 4,
        ),
      ];

      ctrlHistorico.concluidos = [
        PreparoResumo(
          idPreparo: 'prep_concluido_2',
          idReceita: 'rec_3',
          idVersao: 'versao_3',
          tituloReceita: 'Pão Caseiro',
          iniciadoEm: agora.subtract(const Duration(days: 1)),
          concluidoEm: agora.subtract(const Duration(days: 1)),
          ordemEtapaAtual: 2,
          totalEtapas: 2,
          estrelas: 4,
        ),
      ];

      await tester.pumpWidget(wrap(InicioTela(
        controllerHistorico: ctrlHistorico,
        controllerPreparo: ctrlPreparo,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Continue de onde parou'), findsOneWidget);
      expect(find.text('Risoto de Cogumelos'), findsOneWidget);
      expect(find.text('Etapa 2 de 4'), findsOneWidget);

      expect(find.text('Feitas recentemente'), findsOneWidget);
      expect(find.text('Pão Caseiro'), findsOneWidget);
      expect(find.text('4 estrelas'), findsOneWidget);
    });

    testWidgets('3.4 Navegação principal atualiza Início e Histórico ao alternar abas', (tester) async {
      final ctrlHistorico = ControllerHistorico(repositorio: RepositorioPreparos(forcarMemoria: true));

      await tester.pumpWidget(wrap(NavegacaoPrincipal(
        controllerHistorico: ctrlHistorico,
      )));
      await tester.pumpAndSettle();

      // Clica na aba Histórico
      await tester.tap(find.text('Histórico'));
      await tester.pumpAndSettle();
      expect(find.byType(HistoricoTela), findsOneWidget);

      // Volta para a aba Início
      await tester.tap(find.text('Início'));
      await tester.pumpAndSettle();
      expect(find.byType(InicioTela), findsOneWidget);
    });

    testWidgets('4.2 Detalhe do Histórico permite alterar a avaliação por diálogo', (tester) async {
      final ctrlHistorico = ControllerHistorico(repositorio: RepositorioPreparos(forcarMemoria: true));
      ctrlHistorico.detalhePreparo = criarPreparoMock(etapaAtual: 2, concluido: true, estrelas: 3);

      await tester.pumpWidget(wrap(DetalhePreparoTela(
        idPreparo: 'prep_mock_1',
        controller: ctrlHistorico,
      )));
      await tester.pumpAndSettle();

      expect(find.text('3 de 5 estrelas'), findsOneWidget);
      expect(find.text('Alterar'), findsOneWidget);

      await tester.tap(find.text('Alterar'));
      await tester.pumpAndSettle();

      expect(find.text('Avaliação Pessoal'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Avaliação Pessoal'), findsNothing);
    });

    testWidgets('5.4 Layout adaptável e acessível em 360 dp com texto a 200%', (tester) async {
      final ctrlPreparo = ControllerPreparo(repositorio: RepositorioPreparos(forcarMemoria: true));
      ctrlPreparo.preparoAtual = criarPreparoMock();

      await tester.pumpWidget(wrap(
        ChecklistPreparoTela(controller: ctrlPreparo),
        size: const Size(360, 640),
        textScaleFactor: 2.0,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Seguir para as etapas'), findsOneWidget);
    });
  });
}
