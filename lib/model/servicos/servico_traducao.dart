import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart';
import '../repositorios/repositorio_themealdb.dart';
import 'quebrador_instrucoes.dart';
import 'tradutor_themealdb.dart';

/// Serviço de tradução culinária e termos gerais entre Português e Inglês.
class ServicoTraducao {
  final GoogleTranslator _translator;

  ServicoTraducao({GoogleTranslator? translator})
      : _translator = translator ?? GoogleTranslator();

  // Cache em memória para evitar requisições repetidas
  final Map<String, String> _cachePtParaEn = {};
  final Map<String, String> _cacheEnParaPt = {};

  // Mapeamento bidirecional das categorias oficiais da TheMealDB
  static const Map<String, String> _categoriasEnParaPt = {
    'beef': 'Carne Bovina',
    'chicken': 'Frango',
    'dessert': 'Sobremesa',
    'lamb': 'Cordeiro',
    'miscellaneous': 'Diversos',
    'pasta': 'Massas',
    'pork': 'Carne Suína',
    'seafood': 'Frutos do Mar',
    'side': 'Acompanhamento',
    'starter': 'Entrada',
    'vegan': 'Vegano',
    'vegetarian': 'Vegetariano',
    'breakfast': 'Café da Manhã',
    'goat': 'Carne de Cabra',
  };

  static const Map<String, String> _categoriasPtParaEn = {
    'carne bovina': 'Beef',
    'carne': 'Beef',
    'frango': 'Chicken',
    'sobremesa': 'Dessert',
    'sobremesas': 'Dessert',
    'doce': 'Dessert',
    'cordeiro': 'Lamb',
    'diversos': 'Miscellaneous',
    'massas': 'Pasta',
    'massa': 'Pasta',
    'macarrão': 'Pasta',
    'carne suína': 'Pork',
    'porco': 'Pork',
    'frutos do mar': 'Seafood',
    'peixe': 'Seafood',
    'peixes': 'Seafood',
    'camarão': 'Seafood',
    'acompanhamento': 'Side',
    'acompanhamentos': 'Side',
    'entrada': 'Starter',
    'entradas': 'Starter',
    'vegano': 'Vegan',
    'vegetariano': 'Vegetarian',
    'café da manhã': 'Breakfast',
    'cafe da manha': 'Breakfast',
    'carne de cabra': 'Goat',
  };

  // Termos culinários frequentes para tradução instantânea sem latência
  static const Map<String, String> _termosRapidosPtParaEn = {
    'frango': 'chicken',
    'galinha': 'chicken',
    'carne': 'beef',
    'peixe': 'fish',
    'arroz': 'rice',
    'alho': 'garlic',
    'cebola': 'onion',
    'tomate': 'tomato',
    'batata': 'potato',
    'cenoura': 'carrot',
    'queijo': 'cheese',
    'leite': 'milk',
    'manteiga': 'butter',
    'farinha': 'flour',
    'açúcar': 'sugar',
    'acucar': 'sugar',
    'sal': 'salt',
    'pimenta': 'pepper',
    'ovo': 'egg',
    'ovos': 'eggs',
    'azeite': 'olive oil',
    'óleo': 'oil',
    'oleo': 'oil',
    'bolo': 'cake',
    'torta': 'pie',
    'chocolate': 'chocolate',
    'limão': 'lemon',
    'limao': 'lemon',
    'laranja': 'orange',
    'maçã': 'apple',
    'maca': 'apple',
    'banana': 'banana',
    'morango': 'strawberry',
    'pão': 'bread',
    'pao': 'bread',
    'sopa': 'soup',
    'salada': 'salad',
    'molho': 'sauce',
    'camarão': 'shrimp',
    'camarao': 'shrimp',
    'cogumelo': 'mushroom',
    'cogumelos': 'mushrooms',
  };

  /// Traduz o nome de uma categoria do inglês para exibição em português.
  String categoriaParaPortugues(String categoriaEn) {
    final chave = categoriaEn.trim().toLowerCase();
    return _categoriasEnParaPt[chave] ?? categoriaEn;
  }

  /// Converte uma categoria em português para o nome em inglês aceito pela TheMealDB.
  String categoriaParaIngles(String categoriaPt) {
    final chave = categoriaPt.trim().toLowerCase();
    return _categoriasPtParaEn[chave] ?? categoriaPt;
  }

  /// Traduz um termo de busca digitado pelo usuário (PT -> EN) para consultar o TheMealDB.
  Future<String> termoBuscaParaIngles(String termo) async {
    final limpo = termo.trim();
    if (limpo.isEmpty) return limpo;

    final chave = limpo.toLowerCase();

    // 1. Dicionário rápido em memória
    if (_categoriasPtParaEn.containsKey(chave)) {
      return _categoriasPtParaEn[chave]!;
    }
    if (_termosRapidosPtParaEn.containsKey(chave)) {
      return _termosRapidosPtParaEn[chave]!;
    }

    // 2. Cache
    if (_cachePtParaEn.containsKey(chave)) {
      return _cachePtParaEn[chave]!;
    }

    // 3. Tradução automática via Google Translate
    try {
      final traducao = await _translator.translate(limpo, from: 'pt', to: 'en');
      final resultado = traducao.text.trim();
      _cachePtParaEn[chave] = resultado;
      return resultado;
    } catch (_) {
      // Em falha de conexão, retorna o termo digitado
      return limpo;
    }
  }

  /// Traduz um texto de inglês para português com cache, retry e tratamento de falha.
  Future<String> textoParaPortugues(String textoEn, {int tentativas = 2}) async {
    final limpo = textoEn.trim();
    if (limpo.isEmpty) return limpo;

    if (_cacheEnParaPt.containsKey(limpo)) {
      return _cacheEnParaPt[limpo]!;
    }

    for (int tentativa = 1; tentativa <= tentativas; tentativa++) {
      try {
        final traducao = await _translator.translate(limpo, from: 'en', to: 'pt');
        final resultado = traducao.text.trim();
        if (resultado.isNotEmpty) {
          _cacheEnParaPt[limpo] = resultado;
          return resultado;
        }
      } catch (e) {
        if (tentativa < tentativas) {
          await Future.delayed(const Duration(milliseconds: 250));
        }
      }
    }
    return limpo;
  }

  /// Verifica se um texto culinário parece estar em inglês.
  bool pareceIngles(String texto) {
    final limpo = texto.trim().toLowerCase();
    if (limpo.isEmpty) return false;

    final termosIngles = [
      'preheat', 'oven', 'bake', 'cook', 'heat', 'pan', 'skillet',
      'bowl', 'stir', 'mix', 'whisk', 'season', 'salt', 'pepper',
      'minutes', 'hours', 'temperature', 'boil', 'simmer', 'serve',
      'chicken', 'beef', 'sauce', 'water', 'oil', 'butter', 'flour',
      'sugar', 'chopped', 'diced', 'sliced', 'drain', 'medium', 'high'
    ];

    int matches = 0;
    for (final termo in termosIngles) {
      if (limpo.contains(termo)) {
        matches++;
        if (matches >= 2) return true;
      }
    }
    return false;
  }

  /// Traduz uma [FichaTheMealDb] completa (título, categoria, ingredientes, medidas e instruções passo a passo) para Português/BR.
  Future<FichaTheMealDb> traduzirFichaParaPortugues(FichaTheMealDb fichaOriginal) async {
    try {
      // 1. Tradução do título e categoria
      final tituloFuturo = textoParaPortugues(fichaOriginal.strMeal);
      final categoriaPt = categoriaParaPortugues(fichaOriginal.categoria);

      // 2. Tradução das instruções divididas em etapas individuais para máxima confiabilidade
      final etapasOriginais = QuebradorInstrucoes.dividirEmEtapas(fichaOriginal.instrucoes);
      final etapasTraduzidasFuturo = Future.wait(
        etapasOriginais.map((etapa) => textoParaPortugues(etapa)),
      );

      // 3. Tradução dos ingredientes e medidas
      final ingredientesTraduzidos = await Future.wait(
        fichaOriginal.ingredientes.map((item) async {
          final nomePt = await textoParaPortugues(item.nome);
          final medidaPt = item.medida.isNotEmpty
              ? await textoParaPortugues(item.medida)
              : '';
          return ItemFichaExterna(
            ordem: item.ordem,
            nome: nomePt,
            medida: medidaPt,
          );
        }),
      );

      final tituloPt = await tituloFuturo;
      final etapasTraduzidas = await etapasTraduzidasFuturo;
      final instrucoesPt = etapasTraduzidas.isNotEmpty
          ? etapasTraduzidas.join('\n\n')
          : await textoParaPortugues(fichaOriginal.instrucoes);

      return FichaTheMealDb(
        idMeal: fichaOriginal.idMeal,
        strMeal: tituloPt,
        categoria: categoriaPt,
        fotoRemota: fichaOriginal.fotoRemota,
        instrucoes: instrucoesPt,
        ingredientes: ingredientesTraduzidos,
      );
    } catch (e) {
      debugPrint('Erro ao traduzir ficha: $e. Mantendo original.');
      return fichaOriginal;
    }
  }

  /// Traduz os títulos de uma lista de resumos externos para exibição em Português/BR.
  Future<List<ReceitaExternaResumo>> traduzirResultados(
      List<ReceitaExternaResumo> itens) async {
    try {
      return await Future.wait(
        itens.map((r) async {
          final tituloPt = await textoParaPortugues(r.strMeal);
          return ReceitaExternaResumo(
            idMeal: r.idMeal,
            strMeal: tituloPt,
            strMealThumb: r.strMealThumb,
          );
        }),
      );
    } catch (_) {
      return itens;
    }
  }
}
