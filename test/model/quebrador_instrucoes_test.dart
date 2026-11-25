import 'package:flutter_test/flutter_test.dart';
import 'package:app_receitas/model/servicos/quebrador_instrucoes.dart';

void main() {
  group('QuebradorInstrucoes.dividirEmEtapas', () {
    test('Divide parágrafos separados por quebra de linha dupla', () {
      const texto = 'Pré-aqueça o forno a 180°C.\r\n\r\nMisture os ingredientes na tigela.\r\n\r\nAsse por 30 minutos.';
      final etapas = QuebradorInstrucoes.dividirEmEtapas(texto);

      expect(etapas.length, equals(3));
      expect(etapas[0], equals('Pré-aqueça o forno a 180°C.'));
      expect(etapas[1], equals('Misture os ingredientes na tigela.'));
      expect(etapas[2], equals('Asse por 30 minutos.'));
    });

    test('Divide instruções com marcadores STEP 1, STEP 2 e remove marcadores redundantes', () {
      const texto = 'STEP 1\r\nPique as cebolas e o alho.\r\nSTEP 2\r\nAqueça o azeite e refogue.\r\nSTEP 3\r\nSirva imediatamente.';
      final etapas = QuebradorInstrucoes.dividirEmEtapas(texto);

      expect(etapas.length, equals(3));
      expect(etapas[0], equals('Pique as cebolas e o alho.'));
      expect(etapas[1], equals('Aqueça o azeite e refogue.'));
      expect(etapas[2], equals('Sirva imediatamente.'));
    });

    test('Divide instruções com numeração 1., 2. no início de linhas', () {
      const texto = '1. Descasque as batatas.\n2. Cozinhe por 15 minutos em água fervente.\n3. Amasse com manteiga e leite.';
      final etapas = QuebradorInstrucoes.dividirEmEtapas(texto);

      expect(etapas.length, equals(3));
      expect(etapas[0], equals('Descasque as batatas.'));
      expect(etapas[1], equals('Cozinhe por 15 minutos em água fervente.'));
      expect(etapas[2], equals('Amasse com manteiga e leite.'));
    });

    test('Texto único sem quebra permanece como uma única etapa', () {
      const texto = 'Preheat oven to 350 F. Mix ingredients and bake.';
      final etapas = QuebradorInstrucoes.dividirEmEtapas(texto);

      expect(etapas.length, equals(1));
      expect(etapas.first, equals('Preheat oven to 350 F. Mix ingredients and bake.'));
    });

    test('Texto vazio ou com espaços retorna lista vazia', () {
      expect(QuebradorInstrucoes.dividirEmEtapas(''), isEmpty);
      expect(QuebradorInstrucoes.dividirEmEtapas('   \n  '), isEmpty);
    });
  });
}
