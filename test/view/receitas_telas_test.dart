import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_receitas/controller/controller_receitas.dart';
import 'package:app_receitas/model/entidades/entidades.dart';
import 'package:app_receitas/model/repositorios/repositorio_receitas.dart';
import 'package:app_receitas/model/servicos/gerenciador_fotos.dart';
import 'package:app_receitas/view/componentes/imagem_receita.dart';
import 'package:app_receitas/view/telas/ficha_receita_tela.dart';
import 'package:app_receitas/view/telas/formulario_receita_tela.dart';
import 'package:app_receitas/view/telas/minhas_receitas_tela.dart';
import 'package:app_receitas/view/telas/perfil_tela.dart';
import 'package:app_receitas/view/theme/tema.dart';

class SeletorFake implements SeletorGaleria {
  String? retorno;
  @override
  Future<String?> escolherFoto() async => retorno;
}

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: TemaApp.tema,
      home: child,
    );
  }

  group('4.1 a 4.6 Testes de Widget das Telas de Receitas Próprias', () {
    testWidgets('4.2 Perfil exibe acesso a Minhas receitas e abre a tela', (tester) async {
      await tester.pumpWidget(wrap(const PerfilTela()));

      expect(find.text('Cozinheiro Local'), findsOneWidget);
      expect(find.text('Minhas receitas'), findsOneWidget);

      await tester.tap(find.text('Minhas receitas'));
      await tester.pumpAndSettle();

      expect(find.byType(MinhasReceitasTela), findsOneWidget);
    });

    testWidgets('4.2 Minhas receitas exibe estado vazio e botão Nova receita', (tester) async {
      await tester.pumpWidget(wrap(const MinhasReceitasTela()));
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma receita ainda'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Nova receita'), findsOneWidget);
    });

    testWidgets('4.3 Formulário permite adicionar ingredientes e etapas e valida campos', (tester) async {
      final controller = ControllerReceitas();

      await tester.pumpWidget(
        wrap(FormularioReceitaTela(controller: controller)),
      );

      expect(find.text('Nova Receita'), findsOneWidget);
      expect(find.text('Título da receita'), findsOneWidget);

      // Tenta salvar vazio -> deve validar
      await tester.ensureVisible(find.text('Salvar receita'));
      await tester.tap(find.text('Salvar receita'));
      await tester.pumpAndSettle();

      expect(find.text('Informe o título da receita'), findsOneWidget);

      // Preenche título
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Título da receita'),
        'Panqueca Fit',
      );

      // Adiciona mais um ingrediente e etapa
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Adicionar'));
      await tester.tap(find.widgetWithText(TextButton, 'Adicionar'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(TextButton, 'Adicionar etapa'));
      await tester.tap(find.widgetWithText(TextButton, 'Adicionar etapa'));
      await tester.pumpAndSettle();

      expect(find.text('Ingrediente 2'), findsOneWidget);
      expect(find.text('Etapa 2'), findsOneWidget);
    });

    testWidgets('4.4 Ficha da receita exibe versão, selos, ingredientes e etapas', (tester) async {
      final controller = ControllerReceitas();
      const idRec = 'rec-ficha-teste';

      controller.receitaSelecionada = ReceitaCompleta(
        receita: const Receita(
          idReceita: idRec,
          idAutor: 'autor-1',
          origem: 'usuario',
          visibilidade: 'privada',
          estadoModeracao: 'liberada',
        ),
        versao: const VersaoReceita(
          idVersao: 'ver-1',
          idReceita: idRec,
          numeroVersao: 1,
          titulo: 'Waffle de Canela',
          categoria: 'Sem categoria',
        ),
        itens: const [
          ItemReceitaDetalhado(
            idItem: 'itm-1',
            idIngrediente: 'ing-1',
            nomeIngrediente: 'Farinha de Aveia',
            ordem: 1,
            medida: '1 xícara',
          ),
          ItemReceitaDetalhado(
            idItem: 'itm-2',
            idIngrediente: 'ing-2',
            nomeIngrediente: 'Canela em Pó',
            ordem: 2,
            medida: 'a gosto',
          ),
        ],
        etapas: const [
          Etapa(
            idEtapa: 'etp-1',
            idVersao: 'ver-1',
            ordem: 1,
            instrucao: 'Misture os ingredientes em uma tigela.',
          ),
          Etapa(
            idEtapa: 'etp-2',
            idVersao: 'ver-1',
            ordem: 2,
            instrucao: 'Coloque na máquina de waffle por 5 minutos.',
          ),
        ],
      );

      await tester.pumpWidget(
        wrap(FichaReceitaTela(idReceita: idRec, controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waffle de Canela'), findsWidgets);
      expect(find.text('Privada'), findsOneWidget);
      expect(find.text('Salvo no aparelho'), findsOneWidget);
      expect(find.text('Versão 1'), findsOneWidget);
      expect(find.text('Farinha de Aveia'), findsOneWidget);
      expect(find.text('1 xícara'), findsOneWidget);
      expect(find.text('Canela em Pó'), findsOneWidget);
      expect(find.text('a gosto'), findsOneWidget);
      expect(find.text('Misture os ingredientes em uma tigela.'), findsOneWidget);
    });

    testWidgets('4.5 Diálogo de exclusão com Excluir e Cancelar', (tester) async {
      final controller = ControllerReceitas();
      const idRec = 'rec-exclusao';

      controller.receitaSelecionada = const ReceitaCompleta(
        receita: Receita(
          idReceita: idRec,
          origem: 'usuario',
        ),
        versao: VersaoReceita(
          idVersao: 'ver-1',
          idReceita: idRec,
          numeroVersao: 1,
          titulo: 'Pão de Queijo',
          categoria: 'Sem categoria',
        ),
        itens: [],
        etapas: [],
      );

      await tester.pumpWidget(
        wrap(FichaReceitaTela(idReceita: idRec, controller: controller)),
      );
      await tester.pumpAndSettle();

      // Clicar no botão de lixeira no AppBar
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Excluir receita?'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Excluir'), findsOneWidget);

      // Cancelar não fecha a tela
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Excluir receita?'), findsNothing);
      expect(find.text('Pão de Queijo'), findsWidgets);
    });

    testWidgets('4.6 Layout responsivo em 360 dp de largura com texto a 200%', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2.0),
            size: Size(360, 640),
          ),
          child: wrap(const MinhasReceitasTela()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MinhasReceitasTela), findsOneWidget);
      expect(find.text('Minhas Receitas'), findsOneWidget);
    });

    testWidgets('4.7 ImagemReceita renderiza Image.network para URL e placeholder quando nulo', (tester) async {
      await tester.pumpWidget(
        wrap(
          const Column(
            children: [
              ImagemReceita(
                caminhoOuUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
                width: 100,
                height: 100,
              ),
              ImagemReceita(
                caminhoOuUrl: null,
                width: 100,
                height: 100,
              ),
            ],
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Sem foto cadastrada'), findsOneWidget);
    });

    testWidgets('4.8 Formulário atualiza prévia ao colar link da imagem', (tester) async {
      final controller = ControllerReceitas();
      await tester.pumpWidget(
        wrap(FormularioReceitaTela(controller: controller)),
      );

      expect(find.text('Nenhuma foto selecionada'), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(TextFormField, 'Ou cole o link da imagem (URL)'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ou cole o link da imagem (URL)'),
        'https://exemplo.com/bolo.jpg',
      );
      await tester.pumpAndSettle();

      expect(find.text('Trocar foto'), findsOneWidget);
      expect(find.text('Remover foto'), findsOneWidget);
      expect(find.byType(ImagemReceita), findsOneWidget);
    });

    testWidgets('4.9 Formulário renderiza campo de categoria e permite selecionar', (tester) async {
      final controller = ControllerReceitas();
      await tester.pumpWidget(
        wrap(FormularioReceitaTela(controller: controller)),
      );

      expect(find.text('Categoria'), findsOneWidget);
      expect(find.text('Sem categoria'), findsOneWidget);

      await tester.tap(find.text('Sem categoria'));
      await tester.pumpAndSettle();

      expect(find.text('Sobremesa'), findsWidgets);
      await tester.tap(find.text('Sobremesa').last);
      await tester.pumpAndSettle();

      expect(find.text('Sobremesa'), findsOneWidget);
    });
  });
}
