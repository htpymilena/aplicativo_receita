/// Serviço de normalização única de nomes de ingredientes.
/// Converte para minúsculas, remove acentos comuns e reduz espaços duplicados.
class NormalizadorIngredientes {
  static String normalizar(String nome) {
    if (nome.trim().isEmpty) return '';
    var texto = nome.trim().toLowerCase();

    // Mapeamento de acentos do português
    const comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const semAcento = 'aaaaaeeeeiiiiooooouuuucn';
    for (int i = 0; i < comAcento.length; i++) {
      texto = texto.replaceAll(comAcento[i], semAcento[i]);
    }

    // Redução de múltiplos espaços para um único espaço
    texto = texto.replaceAll(RegExp(r'\s+'), ' ');
    return texto;
  }
}
