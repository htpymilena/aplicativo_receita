import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_receitas/controller/controller_exploracao.dart';
import 'package:app_receitas/model/repositorios/repositorio_themealdb.dart';
import 'package:app_receitas/model/repositorios/repositorio_receitas.dart';
import 'package:app_receitas/model/servicos/tradutor_themealdb.dart';

class MockRepositorioTheMealDb extends RepositorioTheMealDb {
  bool falharNaBusca = false;
  Completer<List<ReceitaExternaResumo>>? completerPersonalizado;
  String? ultimoModoChamado;
  String? ultimoTermoChamado;

  @override
  Future<List<ReceitaExternaResumo>> buscarPorNome(String nome) async {
    ultimoModoChamado = 'nome';
    ultimoTermoChamado = nome;
    if (falharNaBusca) throw StateError('Erro de conexão simulado');
    if (completerPersonalizado != null) return await completerPersonalizado!.future;
    if (nome == 'vazio' || nome == 'empty') return [];
    return const [
      ReceitaExternaResumo(idMeal: '52772', strMeal: 'Teriyaki Chicken Casserole', strMealThumb: 'http://foto.jpg'),
    ];
  }

  @override
  Future<List<ReceitaExternaResumo>> buscarPorCategoria(String categoria) async {
    ultimoModoChamado = 'categoria';
    ultimoTermoChamado = categoria;
    if (falharNaBusca) throw StateError('Erro de conexão simulado');
    if (completerPersonalizado != null) return await completerPersonalizado!.future;
    return const [
      ReceitaExternaResumo(idMeal: '52773', strMeal: 'Chicken Handi', strMealThumb: 'http://foto2.jpg'),
    ];
  }

  @override
  Future<List<ReceitaExternaResumo>> buscarPorIngrediente(String ingrediente) async {
    ultimoModoChamado = 'ingrediente';
    ultimoTermoChamado = ingrediente;
    if (falharNaBusca) throw StateError('Erro de conexão simulado');
    if (completerPersonalizado != null) return await completerPersonalizado!.future;
    return const [
      ReceitaExternaResumo(idMeal: '52774', strMeal: 'Chicken Couscous', strMealThumb: 'http://foto3.jpg'),
    ];
  }

  @override
  Future<List<String>> listarCategorias() async {
    return const ['Chicken', 'Dessert'];
  }

  @override
  Future<FichaTheMealDb?> obterDetalhesPorId(String id) async {
    if (falharNaBusca) throw StateError('Erro de conexão');
    return FichaTheMealDb(
      idMeal: id,
      strMeal: 'Prato Online',
      categoria: 'Chicken',
      fotoRemota: 'http://foto.jpg',
      instrucoes: 'Cozinhe tudo',
      ingredientes: const [
        ItemFichaExterna(ordem: 1, nome: 'Frango', medida: '500g'),
      ],
    );
  }
}

void main() {
  late MockRepositorioTheMealDb mockApi;
  late RepositorioReceitas repoReceitasMem;
  late ControllerExploracao controller;

  setUp(() {
    mockApi = MockRepositorioTheMealDb();
    repoReceitasMem = RepositorioReceitas(forcarMemoria: true);
    controller = ControllerExploracao(
      repositorioTheMealDb: mockApi,
      repositorioReceitas: repoReceitasMem,
    );
    controller.definirUsuario('usr-teste-exploracao');
  });

  group('4.1 ControllerExploracao - Modos, Estados de Falha e Validações', () {
    test('Busca com termo vazio não dispara requisição e exibe mensagem de validação', () async {
      await controller.buscar('   ');

      expect(controller.erro, equals('Informe um termo para pesquisar.'));
      expect(controller.resultados, isEmpty);
      expect(controller.carregando, isFalse);
      expect(mockApi.ultimoModoChamado, isNull);
    });

    test('Busca nos três modos (nome, categoria, ingrediente) delega corretamente ao repositório', () async {
      // 1. Nome
      controller.alterarModo(ModoBuscaTheMealDb.nome);
      await controller.buscar('chicken');
      expect(mockApi.ultimoModoChamado, equals('nome'));
      expect(mockApi.ultimoTermoChamado, equals('chicken'));
      expect(controller.resultados.length, equals(1));
      expect(controller.resultados.first.idMeal, equals('52772'));
      expect(controller.resultados.first.strMeal, isNotEmpty);

      // 2. Categoria
      controller.alterarModo(ModoBuscaTheMealDb.categoria);
      await controller.buscar('Chicken');
      expect(mockApi.ultimoModoChamado, equals('categoria'));
      expect(controller.resultados.first.idMeal, equals('52773'));
      expect(controller.resultados.first.strMeal, isNotEmpty);

      // 3. Ingrediente
      controller.alterarModo(ModoBuscaTheMealDb.ingrediente);
      await controller.buscar('chicken_breast');
      expect(mockApi.ultimoModoChamado, equals('ingrediente'));
      expect(controller.resultados.first.idMeal, equals('52774'));
      expect(controller.resultados.first.strMeal, isNotEmpty);
    });

    test('Busca sem resultados mantém lista vazia e erro nulo', () async {
      await controller.buscar('vazio');

      expect(controller.carregando, isFalse);
      expect(controller.erro, isNull);
      expect(controller.resultados, isEmpty);
    });

    test('Falha na API define mensagem de erro e nova tentativa limpa o erro', () async {
      // 1. Falha
      mockApi.falharNaBusca = true;
      await controller.buscar('chicken');

      expect(controller.carregando, isFalse);
      expect(controller.erro, contains('Não foi possível carregar as receitas'));
      expect(controller.resultados, isEmpty);

      // 2. Nova tentativa bem-sucedida
      mockApi.falharNaBusca = false;
      await controller.buscar('chicken');

      expect(controller.carregando, isFalse);
      expect(controller.erro, isNull);
      expect(controller.resultados.isNotEmpty, isTrue);
    });

    test('Resposta antiga atrasada é descartada quando uma nova busca é iniciada', () async {
      final completerBusca1 = Completer<List<ReceitaExternaResumo>>();

      // Inicia busca 1 (lenta)
      mockApi.completerPersonalizado = completerBusca1;
      final future1 = controller.buscar('lento');

      // Inicia imediatamente busca 2 (rápida)
      mockApi.completerPersonalizado = null; // retorna resposta padrão rápida
      await controller.buscar('rapido');

      expect(controller.resultados.first.idMeal, equals('52772'));

      // Agora a busca 1 finalmente termina com prato obsoleto
      completerBusca1.complete([
        const ReceitaExternaResumo(idMeal: '99999', strMeal: 'Prato Obsoleto', strMealThumb: null),
      ]);
      await future1;

      // O controller deve ter mantido o resultado da busca 2 mais recente
      expect(controller.resultados.first.idMeal, equals('52772'));
    });

    test('Carrega categorias e receitas salvas na inicialização', () async {
      await controller.inicializar();

      expect(controller.categorias.length, equals(2));
      expect(controller.categorias.first, equals('Chicken'));
      expect(controller.carregandoCategorias, isFalse);
      expect(controller.erroCategorias, isNull);
    });
  });
}
