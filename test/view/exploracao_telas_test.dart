import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_receitas/controller/controller_exploracao.dart';
import 'package:app_receitas/controller/controller_favoritos.dart';
import 'package:app_receitas/controller/controller_preparo.dart';
import 'package:app_receitas/controller/controller_receitas.dart';
import 'package:app_receitas/model/repositorios/repositorio_themealdb.dart';
import 'package:app_receitas/model/repositorios/repositorio_receitas.dart';
import 'package:app_receitas/model/repositorios/repositorio_favoritos.dart';
import 'package:app_receitas/model/repositorios/repositorio_preparos.dart';
import 'package:app_receitas/model/servicos/tradutor_themealdb.dart';
import 'package:app_receitas/view/componentes/cartao_receita.dart';
import 'package:app_receitas/view/telas/exploracao_themealdb_tela.dart';
import 'package:app_receitas/view/telas/ficha_receita_tela.dart';
import 'package:app_receitas/view/theme/tema.dart';

class MockApiTheMealDbWidget extends RepositorioTheMealDb {
  bool falhar = false;
  String? ultimoModo;
  String? ultimoTermo;

  @override
  Future<List<ReceitaExternaResumo>> buscarPorNome(String termo) async {
    ultimoModo = 'nome';
    ultimoTermo = termo;
    if (falhar) throw StateError('Erro de rede simulado');
    if (termo == 'nenhum') return [];
    return const [
      ReceitaExternaResumo(idMeal: '52772', strMeal: 'Teriyaki Chicken Casserole', strMealThumb: null),
    ];
  }

  @override
  Future<List<ReceitaExternaResumo>> buscarPorCategoria(String categoria) async {
    ultimoModo = 'categoria';
    ultimoTermo = categoria;
    if (falhar) throw StateError('Erro de rede simulado');
    return const [
      ReceitaExternaResumo(idMeal: '52773', strMeal: 'Chicken Handi', strMealThumb: null),
    ];
  }

  @override
  Future<List<ReceitaExternaResumo>> buscarPorIngrediente(String ingrediente) async {
    ultimoModo = 'ingrediente';
    ultimoTermo = ingrediente;
    if (falhar) throw StateError('Erro de rede simulado');
    return const [
      ReceitaExternaResumo(idMeal: '52774', strMeal: 'Chicken Couscous', strMealThumb: null),
    ];
  }

  @override
  Future<List<String>> listarCategorias() async {
    return const ['Chicken', 'Dessert', 'Seafood'];
  }

  @override
  Future<FichaTheMealDb?> obterDetalhesPorId(String idMeal) async {
    if (falhar) throw StateError('Erro de rede');
    return FichaTheMealDb(
      idMeal: idMeal,
      strMeal: 'Teriyaki Chicken Casserole',
      categoria: 'Chicken',
      fotoRemota: null,
      instrucoes: 'Misture os ingredientes e asse por 30 minutos.',
      ingredientes: const [
        ItemFichaExterna(ordem: 1, nome: 'chicken breasts', medida: '2 pounds'),
        ItemFichaExterna(ordem: 2, nome: 'soy sauce', medida: '3/4 cup'),
      ],
    );
  }
}

void main() {
  late MockApiTheMealDbWidget mockApi;
  late RepositorioReceitas repoReceitas;
  late RepositorioFavoritos repoFavoritos;
  late RepositorioPreparos repoPreparos;

  late ControllerExploracao controllerExploracao;
  late ControllerReceitas controllerReceitas;
  late ControllerFavoritos controllerFavoritos;
  late ControllerPreparo controllerPreparo;

  setUp(() {
    RepositorioReceitas.limparMemoriaReceitasExternas();
    RepositorioFavoritos.limparMemoria();
    RepositorioPreparos.limparMemoriaWeb();

    mockApi = MockApiTheMealDbWidget();
    repoReceitas = RepositorioReceitas(forcarMemoria: true);
    repoFavoritos = RepositorioFavoritos(forcarMemoria: true);
    repoPreparos = RepositorioPreparos(forcarMemoria: true);

    controllerExploracao = ControllerExploracao(
      repositorioTheMealDb: mockApi,
      repositorioReceitas: repoReceitas,
    );
    controllerExploracao.definirUsuario('usr-teste-widget');

    controllerReceitas = ControllerReceitas(
      repositorio: repoReceitas,
    );
    controllerReceitas.definirUsuario('usr-teste-widget');

    controllerFavoritos = ControllerFavoritos(
      repositorio: repoFavoritos,
      repositorioReceitas: repoReceitas,
      repositorioTheMealDb: mockApi,
    );

    controllerPreparo = ControllerPreparo(
      repositorio: repoPreparos,
    );
  });

  Widget criarApp(Widget tela) {
    return MaterialApp(
      theme: TemaApp.tema,
      home: tela,
    );
  }

  group('4.2 Tela de Exploração TheMealDB - Modos, Atalhos e Receitas Salvas', () {
    testWidgets('Exibe os 3 modos de busca e permite alternar entre eles', (tester) async {
      await tester.pumpWidget(
        criarApp(
          ExploracaoTheMealDbTela(
            controller: controllerExploracao,
            controllerReceitas: controllerReceitas,
            controllerFavoritos: controllerFavoritos,
            controllerPreparo: controllerPreparo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Explorar TheMealDB'), findsOneWidget);
      expect(find.text('Nome'), findsOneWidget);
      expect(find.text('Categoria'), findsOneWidget);
      expect(find.text('Ingrediente'), findsOneWidget);

      // Alterna para Categoria
      await tester.tap(find.text('Categoria'));
      await tester.pumpAndSettle();
      expect(controllerExploracao.modoBusca, equals(ModoBuscaTheMealDb.categoria));

      // Alterna para Ingrediente
      await tester.tap(find.text('Ingrediente'));
      await tester.pumpAndSettle();
      expect(controllerExploracao.modoBusca, equals(ModoBuscaTheMealDb.ingrediente));
    });

    testWidgets('Atalhos de categoria selecionam o modo e realizam busca', (tester) async {
      await tester.pumpWidget(
        criarApp(
          ExploracaoTheMealDbTela(
            controller: controllerExploracao,
            controllerReceitas: controllerReceitas,
            controllerFavoritos: controllerFavoritos,
            controllerPreparo: controllerPreparo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clica no chip de categoria 'Frango' (mapeado de 'Chicken')
      final chipChicken = find.widgetWithText(ActionChip, 'Frango');
      expect(chipChicken, findsOneWidget);

      await tester.tap(chipChicken);
      await tester.pumpAndSettle();

      expect(controllerExploracao.modoBusca, equals(ModoBuscaTheMealDb.categoria));
      expect(mockApi.ultimoModo, equals('categoria'));
      expect(mockApi.ultimoTermo, equals('Chicken'));
      expect(find.text('Chicken Handi'), findsOneWidget);
    });

    testWidgets('Busca sem termo exibe mensagem de validação', (tester) async {
      await tester.pumpWidget(
        criarApp(
          ExploracaoTheMealDbTela(
            controller: controllerExploracao,
            controllerReceitas: controllerReceitas,
            controllerFavoritos: controllerFavoritos,
            controllerPreparo: controllerPreparo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tenta pesquisar sem digitar nada
      await tester.tap(find.byTooltip('Pesquisar'));
      await tester.pumpAndSettle();

      expect(find.text('Informe um termo para pesquisar.'), findsOneWidget);
    });

    testWidgets('Quando a rede falha, exibe erro e permite acessar receitas salvas', (tester) async {
      mockApi.falhar = true;

      await tester.pumpWidget(
        criarApp(
          ExploracaoTheMealDbTela(
            controller: controllerExploracao,
            controllerReceitas: controllerReceitas,
            controllerFavoritos: controllerFavoritos,
            controllerPreparo: controllerPreparo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Digita algo e pesquisa
      await tester.enterText(find.byType(TextField), 'chicken');
      await tester.tap(find.byTooltip('Pesquisar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Não foi possível carregar as receitas'), findsOneWidget);
      expect(find.text('Ver receitas salvas'), findsOneWidget);

      // Clica no botão para ver receitas salvas
      await tester.tap(find.text('Ver receitas salvas'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma receita salva'), findsOneWidget);
    });
  });

  group('4.3 FichaReceitaTela com Origem Externa', () {
    testWidgets('Exibe atribuição Fonte: TheMealDB e oculta botões de editar e excluir', (tester) async {
      // Salva uma cópia externa no repositório
      final ficha = FichaTheMealDb(
        idMeal: '52772',
        strMeal: 'Teriyaki Chicken Casserole',
        categoria: 'Chicken',
        fotoRemota: null,
        instrucoes: 'Instruções completas da TheMealDB',
        ingredientes: const [
          ItemFichaExterna(ordem: 1, nome: 'chicken breasts', medida: '2 pounds'),
        ],
      );
      final salva = await repoReceitas.salvarCopiaExterna(
        idUsuario: 'usr-teste-widget',
        ficha: ficha,
      );

      await tester.pumpWidget(
        criarApp(
          FichaReceitaTela(
            idReceita: salva.receita.idReceita,
            controller: controllerReceitas,
            controllerPreparo: controllerPreparo,
            controllerFavoritos: controllerFavoritos,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Atribuição de fonte presente
      expect(find.text('Fonte: TheMealDB'), findsOneWidget);

      // Ações de editar e excluir ausentes
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);

      // Botão Iniciar receita presente
      expect(find.text('Iniciar receita'), findsOneWidget);
    });
  });

  group('4.4 Favoritar do resultado e sincronização de favoritos externos', () {
    testWidgets('Tocar no coração do resultado favorita sem abrir a ficha e atualiza o estado', (tester) async {
      await tester.pumpWidget(
        criarApp(
          ExploracaoTheMealDbTela(
            controller: controllerExploracao,
            controllerReceitas: controllerReceitas,
            controllerFavoritos: controllerFavoritos,
            controllerPreparo: controllerPreparo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Busca chicken
      await tester.enterText(find.byType(TextField), 'chicken');
      await tester.tap(find.byTooltip('Pesquisar'));
      await tester.pumpAndSettle();

      expect(find.text('Teriyaki Chicken Casserole'), findsOneWidget);
      expect(controllerFavoritos.favoritos, isEmpty);

      // Toca no coração do CartaoReceita
      final cartao = find.byType(CartaoReceita);
      expect(cartao, findsOneWidget);

      final coracao = find.descendant(of: cartao, matching: find.byIcon(Icons.favorite_border));
      expect(coracao, findsOneWidget);

      await tester.tap(coracao);
      await tester.pumpAndSettle();

      // Deve ter favoritado e obtido a cópia
      expect(controllerFavoritos.isFavoritoPorIdThemealdb('52772'), isTrue);
      expect(controllerFavoritos.favoritos.length, equals(1));
      expect(controllerFavoritos.favoritos.first.origem, equals('themealdb'));

      // Ícone agora deve ser de favorito preenchido
      expect(find.descendant(of: cartao, matching: find.byIcon(Icons.favorite)), findsOneWidget);

      // Não abriu a tela de ficha
      expect(find.text('Iniciar receita'), findsNothing);
    });
  });
}
