/// Representação de um item de ingrediente com medida extraído da TheMealDB.
class ItemFichaExterna {
  final String nome;
  final String medida;
  final int ordem;

  const ItemFichaExterna({
    required this.nome,
    required this.medida,
    required this.ordem,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemFichaExterna &&
          runtimeType == other.runtimeType &&
          nome == other.nome &&
          medida == other.medida &&
          ordem == other.ordem;

  @override
  int get hashCode => nome.hashCode ^ medida.hashCode ^ ordem.hashCode;
}

/// Ficha completa e validada proveniente do catálogo TheMealDB.
class FichaTheMealDb {
  final String idMeal;
  final String strMeal;
  final String categoria;
  final String? fotoRemota;
  final String instrucoes;
  final List<ItemFichaExterna> ingredientes;

  const FichaTheMealDb({
    required this.idMeal,
    required this.strMeal,
    required this.categoria,
    this.fotoRemota,
    required this.instrucoes,
    required this.ingredientes,
  });
}

/// Tradutor de JSON da TheMealDB para objetos locais validados.
class TradutorTheMealDb {
  /// Converte o mapa JSON de um prato retornado pela API em uma [FichaTheMealDb].
  /// Valida campos obrigatórios e pareia até 20 ingredientes e medidas.
  static FichaTheMealDb traduzir(Map<String, dynamic> json) {
    final idMeal = json['idMeal']?.toString().trim() ?? '';
    final strMeal = json['strMeal']?.toString().trim() ?? '';
    final strInstructions = json['strInstructions']?.toString().trim() ?? '';

    if (idMeal.isEmpty || strMeal.isEmpty || strInstructions.isEmpty) {
      throw const FormatException(
        'Ficha inválida: idMeal, strMeal e strInstructions são campos obrigatórios.',
      );
    }

    final categoriaRaw = json['strCategory']?.toString().trim();
    final categoria =
        (categoriaRaw != null && categoriaRaw.isNotEmpty) ? categoriaRaw : 'Sem categoria';

    final fotoRaw = json['strMealThumb']?.toString().trim();
    final fotoRemota = (fotoRaw != null && fotoRaw.isNotEmpty) ? fotoRaw : null;

    final itens = <ItemFichaExterna>[];
    int ordem = 1;

    for (int i = 1; i <= 20; i++) {
      final ingKey = 'strIngredient$i';
      final measureKey = 'strMeasure$i';

      final ingRaw = json[ingKey]?.toString().trim();
      if (ingRaw != null && ingRaw.isNotEmpty) {
        final measureRaw = json[measureKey]?.toString().trim() ?? '';
        itens.add(
          ItemFichaExterna(
            nome: ingRaw,
            medida: measureRaw,
            ordem: ordem++,
          ),
        );
      }
    }

    if (itens.isEmpty) {
      throw const FormatException(
        'Ficha inválida: a receita externa deve conter pelo menos um ingrediente utilizável.',
      );
    }

    return FichaTheMealDb(
      idMeal: idMeal,
      strMeal: strMeal,
      categoria: categoria,
      fotoRemota: fotoRemota,
      instrucoes: strInstructions,
      ingredientes: itens,
    );
  }
}
