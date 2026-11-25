/// Utilitário para analisar e dividir textos de instruções (como os do TheMealDB)
/// em etapas estruturadas, ordenadas e limpas.
class QuebradorInstrucoes {
  /// Divide um texto de instruções em uma lista de etapas individuais.
  static List<String> dividirEmEtapas(String texto) {
    final limpo = texto.trim();
    if (limpo.isEmpty) return [];

    final normalizado = limpo
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    List<String> blocos = [];

    // 1. Verifica se há marcadores explícitos "STEP 1", "Passo 1", "PASSO 1"
    final temMarcadorStep = RegExp(
      r'(?:STEP|Step|Passo|PASSO)\s*\d+',
      caseSensitive: false,
    ).hasMatch(normalizado);

    // 2. Verifica se há marcadores numéricos no início de linha: "1. ", "1) "
    final temMarcadorNum = RegExp(
      r'(?:^|\n)\s*\d+[\.\)]\s+',
    ).hasMatch(normalizado);

    if (temMarcadorStep) {
      blocos = normalizado
          .split(RegExp(r'(?=(?:STEP|Step|Passo|PASSO)\s*\d+)', caseSensitive: false))
          .map((b) => b.trim())
          .where((b) => b.isNotEmpty)
          .toList();
    } else if (temMarcadorNum) {
      blocos = normalizado
          .split(RegExp(r'(?=(?:^|\n)\s*\d+[\.\)]\s+)'))
          .map((b) => b.trim())
          .where((b) => b.isNotEmpty)
          .toList();
    } else if (normalizado.contains('\n\n')) {
      // Divide por quebras de parágrafo (\n\n+)
      blocos = normalizado
          .split(RegExp(r'\n\s*\n+'))
          .map((b) => b.trim())
          .where((b) => b.isNotEmpty)
          .toList();
    } else if (normalizado.contains('\n')) {
      // Divide por quebra de linha simples se houver mais de uma linha não vazia
      final linhas = normalizado
          .split('\n')
          .map((b) => b.trim())
          .where((b) => b.isNotEmpty)
          .toList();
      if (linhas.length > 1) {
        blocos = linhas;
      } else {
        blocos = [normalizado];
      }
    } else {
      blocos = [normalizado];
    }

    final resultado = <String>[];
    for (final bloco in blocos) {
      var formatado = bloco.trim();

      // Remove marcadores redundantes de início ("STEP 1:", "Passo 1.", "1.", "1)")
      formatado = formatado.replaceFirst(
        RegExp(r'^(?:STEP|Step|Passo|PASSO)\s*\d+[:.\-\s]*', caseSensitive: false),
        '',
      ).trim();

      formatado = formatado.replaceFirst(
        RegExp(r'^\d+[\.\)][\s\-]*'),
        '',
      ).trim();

      // Transforma quebras de linha internas extras em espaços simples
      formatado = formatado.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();

      if (formatado.isNotEmpty) {
        resultado.add(formatado);
      }
    }

    return resultado.isNotEmpty ? resultado : [limpo];
  }
}
