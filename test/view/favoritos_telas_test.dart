import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_receitas/controller/controller_favoritos.dart';
import 'package:app_receitas/controller/controller_receitas.dart';
import 'package:app_receitas/model/entidades/entidades.dart';
import 'package:app_receitas/model/repositorios/repositorio_favoritos.dart';
import 'package:app_receitas/model/repositorios/repositorio_receitas.dart';
import 'package:app_receitas/view/componentes/cartao_receita.dart';
import 'package:app_receitas/view/telas/favoritos_tela.dart';
import 'package:app_receitas/view/telas/ficha_receita_tela.dart';
import 'package:app_receitas/view/telas/navegacao_principal.dart';
import 'package:app_receitas/view/theme/tema.dart';

class MockRepoFavoritosWidget extends RepositorioFavoritos {
  MockRepoFavoritosWidget({this.repoReceitas}) : super(forcarMemoria: true);

  final MockRepoReceitasWidget? repoReceitas;
  final Set<String> _favs = {};
  bool simularErro = false;

  @override
  Future<bool> ehFavorito({required String idUsuario, required String idReceita}) async {
    return _favs.contains(idReceita);
  }

  @override
  Future<void> adicionarFavorito({
    required String idUsuario,
    required String idReceita,
    DateTime? salvoEm,
  }) async {
    if (simularErro) throw StateError('Erro ao salvar no banco');
    _favs.add(idReceita);
  }

  @override
  Future<void> removerFavorito({
    required String idUsuario,
    required String idReceita,
  }) async {
    if (simularErro) throw StateError('Erro ao remover no banco');
    _favs.remove(idReceita);
  }

  @override
  Future<List<ReceitaResumo>> listarFavoritos(String idUsuario) async {
    if (simularErro) throw StateError('Erro ao listar');
    final lista = <ReceitaResumo>[];
    for (final id in _favs) {
      final rec = repoReceitas?._mockList.where((r) => r.receita.idReceita == id).firstOrNull;
      lista.add(ReceitaResumo(
        idReceita: id,
        titulo: rec?.versao.titulo ?? 'Receita $id',
        categoria: rec?.versao.categoria ?? 'Café',
        numeroVersao: rec?.versao.numeroVersao ?? 1,
      ));
    }
    return lista;
  }
}

class MockRepoReceitasWidget extends RepositorioReceitas {
  MockRepoReceitasWidget() : super(forcarMemoria: true);

  final List<ReceitaCompleta> _mockList = [];

  void adicionarMock(ReceitaCompleta r) {
    _mockList.add(r);
  }

  @override
  Future<List<ReceitaResumo>> listarReceitasProprias(String idAutor) async {
    return _mockList
        .where((r) => r.receita.excluidaEm == null)
        .map((r) => ReceitaResumo(
              idReceita: r.receita.idReceita,
              titulo: r.versao.titulo,
              categoria: r.versao.categoria,
              fotoLocal: r.versao.fotoLocal,
              numeroVersao: r.versao.numeroVersao,
            ))
        .toList();
  }

  @override
  Future<ReceitaCompleta?> obterReceitaPorId({
    required String idReceita,
    String? idAutor,
    String? idUsuario,
  }) async {
    return _mockList.where((r) => r.receita.idReceita == idReceita).firstOrNull;
  }

  @override
  Future<bool> excluirReceitaLogica({
    required String idReceita,
    required String idAutor,
  }) async {
    _mockList.removeWhere((r) => r.receita.idReceita == idReceita);
    return true;
  }
}

void main() {
  Widget wrap(Widget widget) {
    return MaterialApp(
      theme: TemaApp.tema,
      home: widget,
    );
  }

  group('3.2 CartaoReceita - Ação de coração', () {
    testWidgets('3.2 Renderiza coração com alvo de ao menos 48 dp e não aciona onTap do cartão', (tester) async {
      bool cartaoClicado = false;
      bool coracaoClicado = false;

      await tester.pumpWidget(
        wrap(
          CartaoReceita(
            titulo: 'Pão de Queijo',
            categoria: 'Lanche',
            ehFavorito: false,
            onFavoritoTap: () => coracaoClicado = true,
            onTap: () => cartaoClicado = true,
          ),
        ),
      );

      // Ícone inicial de desmarcado com tooltip Favoritar
      final botaoCoracao = find.byTooltip('Favoritar');
      expect(botaoCoracao, findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      // Alvo mínimo de toque de 48 dp
      final tamanho = tester.getSize(botaoCoracao);
      expect(tamanho.width, greaterThanOrEqualTo(48.0));
      expect(tamanho.height, greaterThanOrEqualTo(48.0));

      // Tocar no coração
      await tester.tap(botaoCoracao);
      await tester.pumpAndSettle();

      expect(coracaoClicado, isTrue);
      expect(cartaoClicado, isFalse); // Toque no coração NÃO abre o cartão!
    });

    testWidgets('3.2 Coração marcado exibe ícone preenchido e tooltip Remover dos favoritos', (tester) async {
      await tester.pumpWidget(
        wrap(
          CartaoReceita(
            titulo: 'Pão de Queijo',
            categoria: 'Lanche',
            ehFavorito: true,
            onFavoritoTap: () {},
          ),
        ),
      );

      expect(find.byTooltip('Remover dos favoritos'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });
  });

  group('3.3 Integração de ControllerFavoritos na Ficha e Minhas Receitas', () {
    late MockRepoFavoritosWidget repoFav;
    late MockRepoReceitasWidget repoRec;
    late ControllerFavoritos controllerFav;
    late ControllerReceitas controllerRec;

    setUp(() {
      repoRec = MockRepoReceitasWidget();
      repoFav = MockRepoFavoritosWidget(repoReceitas: repoRec);
      controllerFav = ControllerFavoritos(repositorio: repoFav);
      controllerRec = ControllerReceitas(repositorio: repoRec);

      repoRec.adicionarMock(
        const ReceitaCompleta(
          receita: Receita(
            idReceita: 'rec_1',
            idAutor: 'usuario-provisorio-local',
            origem: 'usuario',
            visibilidade: 'privada',
            estadoModeracao: 'liberada',
          ),
          versao: VersaoReceita(
            idVersao: 'ver_1',
            idReceita: 'rec_1',
            numeroVersao: 1,
            titulo: 'Bolo de Fubá',
            categoria: 'Sobremesa',
          ),
          itens: [],
          etapas: [],
        ),
      );
    });

    testWidgets('3.3 Ficha da receita permite favoritar e reflete no controller compartilhado', (tester) async {
      await tester.pumpWidget(
        wrap(
          FichaReceitaTela(
            idReceita: 'rec_1',
            controller: controllerRec,
            controllerFavoritos: controllerFav,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Favoritar'), findsOneWidget);
      expect(controllerFav.isFavorito('rec_1'), isFalse);

      // Toca em favoritar na ficha
      await tester.tap(find.byTooltip('Favoritar'));
      await tester.pumpAndSettle();

      expect(controllerFav.isFavorito('rec_1'), isTrue);
      expect(find.byTooltip('Remover dos favoritos'), findsOneWidget);
    });

    testWidgets('3.3 Erro de gravação restaura o coração anterior e exibe mensagem', (tester) async {
      repoFav.simularErro = true;

      await tester.pumpWidget(
        wrap(
          FichaReceitaTela(
            idReceita: 'rec_1',
            controller: controllerRec,
            controllerFavoritos: controllerFav,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toca em favoritar quando o repositório simula falha
      await tester.tap(find.byTooltip('Favoritar'));
      await tester.pumpAndSettle();

      // Estado é restaurado para desfavoritado
      expect(controllerFav.isFavorito('rec_1'), isFalse);
      expect(find.byTooltip('Favoritar'), findsOneWidget);
      // SnackBar exibido
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('4.1 e 4.2 FavoritosTela e NavegacaoPrincipal', () {
    late MockRepoFavoritosWidget repoFav;
    late MockRepoReceitasWidget repoRec;
    late ControllerFavoritos controllerFav;
    late ControllerReceitas controllerRec;

    setUp(() {
      repoRec = MockRepoReceitasWidget();
      repoFav = MockRepoFavoritosWidget(repoReceitas: repoRec);
      controllerFav = ControllerFavoritos(repositorio: repoFav);
      controllerRec = ControllerReceitas(repositorio: repoRec);

      repoRec.adicionarMock(
        const ReceitaCompleta(
          receita: Receita(
            idReceita: 'rec_10',
            idAutor: 'usuario-provisorio-local',
            origem: 'usuario',
            visibilidade: 'privada',
            estadoModeracao: 'liberada',
          ),
          versao: VersaoReceita(
            idVersao: 'ver_10',
            idReceita: 'rec_10',
            numeroVersao: 1,
            titulo: 'Pizza Margherita',
            categoria: 'Jantar',
          ),
          itens: [],
          etapas: [],
        ),
      );
    });

    testWidgets('4.1 FavoritosTela exibe estado vazio quando sem itens e lista cartões quando favoritada', (tester) async {
      await tester.pumpWidget(
        wrap(
          FavoritosTela(
            controller: controllerFav,
            controllerReceitas: controllerRec,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhum favorito guardado'), findsOneWidget);

      // Adiciona favorito
      await controllerFav.alternarFavorito('rec_10');
      await tester.pumpAndSettle();

      expect(find.text('Pizza Margherita'), findsOneWidget);

      // Remoção direta da lista via coração
      await tester.tap(find.byTooltip('Remover dos favoritos'));
      await tester.pumpAndSettle();

      expect(find.text('Pizza Margherita'), findsNothing);
      expect(find.text('Nenhum favorito guardado'), findsOneWidget);
    });

    testWidgets('4.2 Navegação entre abas sincroniza favoritos sem reiniciar o app', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TemaApp.tema,
          home: NavegacaoPrincipal(
            controllerReceitas: controllerRec,
            controllerFavoritos: controllerFav,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Favorita na aba Início (no cartão de 'Pizza Margherita')
      expect(find.text('Pizza Margherita'), findsOneWidget);
      await tester.tap(find.byTooltip('Favoritar'));
      await tester.pumpAndSettle();

      // Vai para a aba Favoritos
      await tester.tap(find.text('Favoritos'));
      await tester.pumpAndSettle();

      // Receita favoritada está visível na aba Favoritos
      expect(find.text('Pizza Margherita'), findsOneWidget);

      // Desfavorita na aba Favoritos
      await tester.tap(find.byTooltip('Remover dos favoritos'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum favorito guardado'), findsOneWidget);

      // Retorna para o Início
      await tester.tap(find.text('Início'));
      await tester.pumpAndSettle();

      // Coração no Início reflete desmarcado
      expect(find.byTooltip('Favoritar'), findsOneWidget);
    });
  });
}
