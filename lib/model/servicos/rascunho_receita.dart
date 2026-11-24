/// Representação de um item no rascunho de criação/edição de receita.
class RascunhoItemReceita {
  final String nomeIngrediente;
  final String medida;

  const RascunhoItemReceita({
    required this.nomeIngrediente,
    required this.medida,
  });

  RascunhoItemReceita copyWith({
    String? nomeIngrediente,
    String? medida,
  }) {
    return RascunhoItemReceita(
      nomeIngrediente: nomeIngrediente ?? this.nomeIngrediente,
      medida: medida ?? this.medida,
    );
  }
}

/// Rascunho que encapsula os dados da receita antes ou durante a persistência.
class RascunhoReceita {
  final String? idReceita;
  final String titulo;
  final String? categoria;
  final List<RascunhoItemReceita> itens;
  final List<String> etapas;
  final String? fotoAtual; // caminho relativo já salvo no banco
  final String? novaFotoCaminho; // arquivo temporário escolhido na galeria
  final bool removerFoto;

  const RascunhoReceita({
    this.idReceita,
    required this.titulo,
    this.categoria,
    required this.itens,
    required this.etapas,
    this.fotoAtual,
    this.novaFotoCaminho,
    this.removerFoto = false,
  });

  RascunhoReceita copyWith({
    String? idReceita,
    String? titulo,
    String? categoria,
    List<RascunhoItemReceita>? itens,
    List<String>? etapas,
    String? fotoAtual,
    String? novaFotoCaminho,
    bool? removerFoto,
  }) {
    return RascunhoReceita(
      idReceita: idReceita ?? this.idReceita,
      titulo: titulo ?? this.titulo,
      categoria: categoria ?? this.categoria,
      itens: itens ?? this.itens,
      etapas: etapas ?? this.etapas,
      fotoAtual: fotoAtual ?? this.fotoAtual,
      novaFotoCaminho: novaFotoCaminho ?? this.novaFotoCaminho,
      removerFoto: removerFoto ?? this.removerFoto,
    );
  }
}

/// Resultado da validação do rascunho.
class ResultadoValidacao {
  final bool valido;
  final String? erroTitulo;
  final Map<int, String> errosIngredientes;
  final Map<int, String> errosMedidas;
  final Map<int, String> errosEtapas;
  final String? erroGeral;

  const ResultadoValidacao({
    required this.valido,
    this.erroTitulo,
    this.errosIngredientes = const {},
    this.errosMedidas = const {},
    this.errosEtapas = const {},
    this.erroGeral,
  });
}

/// Validador das regras de criação e edição de receitas próprias.
class ValidadorReceita {
  static ResultadoValidacao validar(RascunhoReceita rascunho) {
    String? erroTitulo;
    String? erroGeral;
    final errosIngredientes = <int, String>{};
    final errosMedidas = <int, String>{};
    final errosEtapas = <int, String>{};

    // 1. Validação do título
    if (rascunho.titulo.trim().isEmpty) {
      erroTitulo = 'Informe o título da receita';
    }

    // 2. Validação de ingredientes / itens
    final itensLimpos = rascunho.itens
        .where((it) => it.nomeIngrediente.trim().isNotEmpty || it.medida.trim().isNotEmpty)
        .toList();

    if (rascunho.itens.isEmpty || itensLimpos.isEmpty) {
      erroGeral = 'A receita deve ter ao menos um ingrediente';
    } else {
      for (int i = 0; i < rascunho.itens.length; i++) {
        final item = rascunho.itens[i];
        final nome = item.nomeIngrediente.trim();
        final medida = item.medida.trim();

        if (nome.isEmpty && medida.isNotEmpty) {
          errosIngredientes[i] = 'Informe o nome do ingrediente';
        } else if (nome.isNotEmpty && medida.isEmpty) {
          errosMedidas[i] = 'Informe a medida ou "a gosto"';
        }
      }
    }

    // 3. Validação de etapas
    final etapasLimpas = rascunho.etapas
        .where((et) => et.trim().isNotEmpty)
        .toList();

    if (rascunho.etapas.isEmpty || etapasLimpas.isEmpty) {
      erroGeral = (erroGeral == null)
          ? 'A receita deve ter ao menos uma etapa de preparo'
          : '$erroGeral e ao menos uma etapa de preparo';
    } else {
      for (int i = 0; i < rascunho.etapas.length; i++) {
        if (rascunho.etapas[i].trim().isEmpty) {
          errosEtapas[i] = 'Descreva a instrução desta etapa';
        }
      }
    }

    final bool ehValido = erroTitulo == null &&
        erroGeral == null &&
        errosIngredientes.isEmpty &&
        errosMedidas.isEmpty &&
        errosEtapas.isEmpty;

    return ResultadoValidacao(
      valido: ehValido,
      erroTitulo: erroTitulo,
      errosIngredientes: errosIngredientes,
      errosMedidas: errosMedidas,
      errosEtapas: errosEtapas,
      erroGeral: erroGeral,
    );
  }
}
