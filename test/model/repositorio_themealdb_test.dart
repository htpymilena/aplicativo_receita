import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app_receitas/model/repositorios/repositorio_themealdb.dart';
import 'package:app_receitas/model/servicos/tradutor_themealdb.dart';

void main() {
  group('1.1 RepositorioTheMealDb - Cliente HTTP e Endpoints', () {
    test('buscarPorNome constrói URL correta com parâmetros codificados', () async {
      late Uri uriChamada;
      final mockClient = MockClient((request) async {
        uriChamada = request.url;
        return http.Response(
          json.encode({
            'meals': [
              {
                'idMeal': '52772',
                'strMeal': 'Teriyaki Chicken Casserole',
                'strMealThumb': 'https://www.themealdb.com/images/media/meals/wvpsxx1468256321.jpg'
              }
            ]
          }),
          200,
        );
      });

      final repo = RepositorioTheMealDb(client: mockClient, chave: '1');
      final resultados = await repo.buscarPorNome('chicken pie');

      expect(uriChamada.scheme, 'https');
      expect(uriChamada.host, 'www.themealdb.com');
      expect(uriChamada.path, '/api/json/v1/1/search.php');
      expect(uriChamada.queryParameters['s'], 'chicken pie');
      expect(resultados.length, 1);
      expect(resultados.first.idMeal, '52772');
      expect(resultados.first.strMeal, 'Teriyaki Chicken Casserole');
    });

    test('buscarPorCategoria e buscarPorIngrediente chamam filter.php corretamente', () async {
      final mockClient = MockClient((request) async {
        if (request.url.queryParameters.containsKey('c')) {
          expect(request.url.queryParameters['c'], 'Seafood');
        } else if (request.url.queryParameters.containsKey('i')) {
          expect(request.url.queryParameters['i'], 'chicken_breast');
        }
        return http.Response(
          json.encode({
            'meals': [
              {'idMeal': '1', 'strMeal': 'Prato Teste', 'strMealThumb': 'http://img.com'}
            ]
          }),
          200,
        );
      });

      final repo = RepositorioTheMealDb(client: mockClient);
      final porCat = await repo.buscarPorCategoria('Seafood');
      expect(porCat.length, 1);

      final porIng = await repo.buscarPorIngrediente('chicken_breast');
      expect(porIng.length, 1);
    });

    test('listarCategorias extrai lista de categorias', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'meals': [
              {'strCategory': 'Beef'},
              {'strCategory': 'Chicken'},
              {'strCategory': 'Dessert'},
            ]
          }),
          200,
        );
      });

      final repo = RepositorioTheMealDb(client: mockClient);
      final categorias = await repo.listarCategorias();
      expect(categorias, ['Beef', 'Chicken', 'Dessert']);
    });

    test('Respostas vazias retornam lista vazia ou nulo', () async {
      final mockClient = MockClient((request) async {
        return http.Response(json.encode({'meals': null}), 200);
      });

      final repo = RepositorioTheMealDb(client: mockClient);
      final busca = await repo.buscarPorNome('inexistente');
      expect(busca, isEmpty);

      final detalhe = await repo.obterDetalhesPorId('99999');
      expect(detalhe, isNull);
    });

    test('Tratamento de status HTTP de erro', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server error', 500);
      });

      final repo = RepositorioTheMealDb(client: mockClient);
      expect(() => repo.buscarPorNome('teste'), throwsA(isA<http.ClientException>()));
    });

    test('Tratamento de timeout configurável', () async {
      final mockClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return http.Response('{}', 200);
      });

      final repo = RepositorioTheMealDb(
        client: mockClient,
        timeout: const Duration(milliseconds: 10),
      );
      expect(() => repo.buscarPorNome('lento'), throwsA(isA<TimeoutException>()));
    });
  });

  group('1.2 TradutorTheMealDb - Pareamento e Validação da Ficha', () {
    test('Traduz ficha com 20 ingredientes, preservando ordem e instruções com quebras', () {
      final jsonExemplo = {
        'idMeal': '52772',
        'strMeal': 'Teriyaki Chicken Casserole',
        'strCategory': 'Chicken',
        'strMealThumb': 'https://www.themealdb.com/images/media/meals/wvpsxx1468256321.jpg',
        'strInstructions': 'Preheat oven to 350° F.\r\nSpray a 9x13-inch baking dish.\r\nBake for 30 minutes.',
        'strIngredient1': 'soy sauce',
        'strMeasure1': '3/4 cup',
        'strIngredient2': 'water',
        'strMeasure2': '1/2 cup',
        'strIngredient3': 'brown sugar',
        'strMeasure3': '', // Medida vazia
        'strIngredient4': 'ground ginger',
        'strMeasure4': '1/2 tsp',
        'strIngredient5': '', // Vazio, deve ser ignorado
        'strMeasure5': '1 tsp',
        'strIngredient6': null, // Nulo, deve ser ignorado
      };

      final ficha = TradutorTheMealDb.traduzir(jsonExemplo);

      expect(ficha.idMeal, '52772');
      expect(ficha.strMeal, 'Teriyaki Chicken Casserole');
      expect(ficha.categoria, 'Chicken');
      expect(ficha.fotoRemota, 'https://www.themealdb.com/images/media/meals/wvpsxx1468256321.jpg');
      expect(ficha.instrucoes, contains('Preheat oven to 350° F.\r\nSpray a 9x13-inch baking dish.'));

      expect(ficha.ingredientes.length, 4);
      expect(ficha.ingredientes[0].nome, 'soy sauce');
      expect(ficha.ingredientes[0].medida, '3/4 cup');
      expect(ficha.ingredientes[0].ordem, 1);

      expect(ficha.ingredientes[1].nome, 'water');
      expect(ficha.ingredientes[1].medida, '1/2 cup');
      expect(ficha.ingredientes[1].ordem, 2);

      // Medida vazia aceita sem inventar quantidade
      expect(ficha.ingredientes[2].nome, 'brown sugar');
      expect(ficha.ingredientes[2].medida, '');
      expect(ficha.ingredientes[2].ordem, 3);

      expect(ficha.ingredientes[3].nome, 'ground ginger');
      expect(ficha.ingredientes[3].medida, '1/2 tsp');
      expect(ficha.ingredientes[3].ordem, 4);
    });

    test('Recusa ficha com campos obrigatórios ausentes ou sem ingredientes válidos', () {
      // Sem idMeal
      expect(
        () => TradutorTheMealDb.traduzir({
          'strMeal': 'Bolo',
          'strInstructions': 'Asse.',
          'strIngredient1': 'Ovo',
        }),
        throwsA(isA<FormatException>()),
      );

      // Sem strMeal
      expect(
        () => TradutorTheMealDb.traduzir({
          'idMeal': '123',
          'strInstructions': 'Asse.',
          'strIngredient1': 'Ovo',
        }),
        throwsA(isA<FormatException>()),
      );

      // Sem strInstructions
      expect(
        () => TradutorTheMealDb.traduzir({
          'idMeal': '123',
          'strMeal': 'Bolo',
          'strIngredient1': 'Ovo',
        }),
        throwsA(isA<FormatException>()),
      );

      // Sem nenhum ingrediente
      expect(
        () => TradutorTheMealDb.traduzir({
          'idMeal': '123',
          'strMeal': 'Bolo',
          'strInstructions': 'Asse.',
          'strIngredient1': '',
          'strIngredient2': '   ',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
