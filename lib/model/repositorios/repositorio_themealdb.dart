import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../servicos/tradutor_themealdb.dart';

/// Resumo de receita externa retornado pelas consultas de busca da TheMealDB.
class ReceitaExternaResumo {
  final String idMeal;
  final String strMeal;
  final String? strMealThumb;

  const ReceitaExternaResumo({
    required this.idMeal,
    required this.strMeal,
    this.strMealThumb,
  });

  factory ReceitaExternaResumo.fromJson(Map<String, dynamic> json) {
    return ReceitaExternaResumo(
      idMeal: json['idMeal']?.toString() ?? '',
      strMeal: json['strMeal']?.toString() ?? '',
      strMealThumb: json['strMealThumb']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceitaExternaResumo &&
          runtimeType == other.runtimeType &&
          idMeal == other.idMeal &&
          strMeal == other.strMeal &&
          strMealThumb == other.strMealThumb;

  @override
  int get hashCode => idMeal.hashCode ^ strMeal.hashCode ^ strMealThumb.hashCode;
}

/// Cliente HTTP e repositório de consulta à API pública TheMealDB.
class RepositorioTheMealDb {
  final http.Client _client;
  final String chave;
  final Duration timeout;

  static const String _host = 'www.themealdb.com';

  RepositorioTheMealDb({
    http.Client? client,
    this.chave = '1',
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  /// Busca receitas por nome (/search.php?s=).
  Future<List<ReceitaExternaResumo>> buscarPorNome(String termo) async {
    final termoLimpo = termo.trim();
    if (termoLimpo.isEmpty) {
      return [];
    }

    final uri = Uri.https(_host, '/api/json/v1/$chave/search.php', {'s': termoLimpo});
    return _executarBusca(uri);
  }

  /// Busca receitas por categoria (/filter.php?c=).
  Future<List<ReceitaExternaResumo>> buscarPorCategoria(String categoria) async {
    final categoriaLimpa = categoria.trim();
    if (categoriaLimpa.isEmpty) {
      return [];
    }

    final uri = Uri.https(_host, '/api/json/v1/$chave/filter.php', {'c': categoriaLimpa});
    return _executarBusca(uri);
  }

  /// Busca receitas por ingrediente único (/filter.php?i=).
  Future<List<ReceitaExternaResumo>> buscarPorIngrediente(String ingrediente) async {
    final ingLimpo = ingrediente.trim();
    if (ingLimpo.isEmpty) {
      return [];
    }

    final uri = Uri.https(_host, '/api/json/v1/$chave/filter.php', {'i': ingLimpo});
    return _executarBusca(uri);
  }

  /// Lista nomes de categorias disponíveis (/list.php?c=list ou /categories.php).
  Future<List<String>> listarCategorias() async {
    final uri = Uri.https(_host, '/api/json/v1/$chave/list.php', {'c': 'list'});
    final resposta = await _getJson(uri);
    final meals = resposta['meals'];
    if (meals is! List) {
      return [];
    }

    final categorias = <String>[];
    for (final item in meals) {
      if (item is Map) {
        final cat = item['strCategory']?.toString().trim();
        if (cat != null && cat.isNotEmpty) {
          categorias.add(cat);
        }
      }
    }
    return categorias;
  }

  /// Consulta os detalhes completos de uma receita pelo identificador TheMealDB (/lookup.php?i=).
  Future<FichaTheMealDb?> obterDetalhesPorId(String idMeal) async {
    final idLimpo = idMeal.trim();
    if (idLimpo.isEmpty) {
      return null;
    }

    final uri = Uri.https(_host, '/api/json/v1/$chave/lookup.php', {'i': idLimpo});
    final dados = await _getJson(uri);
    final meals = dados['meals'];
    if (meals is! List || meals.isEmpty) {
      return null;
    }

    final primeiro = meals.first;
    if (primeiro is! Map<String, dynamic>) {
      if (primeiro is Map) {
        return TradutorTheMealDb.traduzir(Map<String, dynamic>.from(primeiro));
      }
      return null;
    }
    return TradutorTheMealDb.traduzir(primeiro);
  }

  Future<List<ReceitaExternaResumo>> _executarBusca(Uri uri) async {
    final dados = await _getJson(uri);
    final meals = dados['meals'];
    if (meals is! List) {
      return [];
    }

    return meals
        .whereType<Map>()
        .map((m) => ReceitaExternaResumo.fromJson(Map<String, dynamic>.from(m)))
        .where((r) => r.idMeal.isNotEmpty && r.strMeal.isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Erro na comunicação com TheMealDB (HTTP ${response.statusCode})',
        uri,
      );
    }

    try {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {};
    } catch (e) {
      throw FormatException('Resposta inválida da TheMealDB: $e');
    }
  }
}
