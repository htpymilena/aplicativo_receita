import 'package:flutter_test/flutter_test.dart';
import 'package:app_receitas/model/servicos/normalizador_ingredientes.dart';
import 'package:app_receitas/model/servicos/rascunho_receita.dart';

void main() {
  group('1.1 e 1.2 Serviços de Normalização e Validação de Receita', () {
    test('1.2 Normalização de ingredientes converte AÇÚCAR, açúcar e acucar para acucar', () {
      expect(NormalizadorIngredientes.normalizar('AÇÚCAR'), equals('acucar'));
      expect(NormalizadorIngredientes.normalizar('açúcar'), equals('acucar'));
      expect(NormalizadorIngredientes.normalizar('acucar'), equals('acucar'));
      expect(NormalizadorIngredientes.normalizar('  Farinha  de   Trigo  '), equals('farinha de trigo'));
      expect(NormalizadorIngredientes.normalizar('ÓLEO DE SOJA'), equals('oleo de soja'));
    });

    test('1.1 Validador de receita aceita receita válida com "a gosto"', () {
      const rascunho = RascunhoReceita(
        titulo: '  Panqueca de Banana  ',
        itens: [
          RascunhoItemReceita(nomeIngrediente: 'Banana nanica', medida: '2 unidades'),
          RascunhoItemReceita(nomeIngrediente: 'Canela em pó', medida: 'a gosto'),
        ],
        etapas: [
          'Amasse as bananas em um prato fundo.',
          'Misture a canela e doure na frigideira.',
        ],
      );

      final resultado = ValidadorReceita.validar(rascunho);
      expect(resultado.valido, isTrue);
      expect(resultado.erroTitulo, isNull);
      expect(resultado.erroGeral, isNull);
    });

    test('1.1 Validador rejeita título vazio ou apenas com espaços', () {
      const rascunho = RascunhoReceita(
        titulo: '   ',
        itens: [
          RascunhoItemReceita(nomeIngrediente: 'Ovo', medida: '1 unidade'),
        ],
        etapas: ['Frite o ovo.'],
      );

      final resultado = ValidadorReceita.validar(rascunho);
      expect(resultado.valido, isFalse);
      expect(resultado.erroTitulo, isNotNull);
    });

    test('1.1 Validador rejeita receita sem ingredientes ou sem etapas', () {
      const semItens = RascunhoReceita(
        titulo: 'Receita Vazia',
        itens: [],
        etapas: ['Misture tudo.'],
      );
      expect(ValidadorReceita.validar(semItens).valido, isFalse);

      const semEtapas = RascunhoReceita(
        titulo: 'Receita Sem Etapas',
        itens: [
          RascunhoItemReceita(nomeIngrediente: 'Água', medida: '1 copo'),
        ],
        etapas: [],
      );
      expect(ValidadorReceita.validar(semEtapas).valido, isFalse);
    });

    test('1.1 Validador identifica item com ingrediente preenchido mas medida vazia', () {
      const itemIncompleto = RascunhoReceita(
        titulo: 'Bolo Simples',
        itens: [
          RascunhoItemReceita(nomeIngrediente: 'Farinha', medida: '   '),
        ],
        etapas: ['Asse no forno.'],
      );

      final resultado = ValidadorReceita.validar(itemIncompleto);
      expect(resultado.valido, isFalse);
      expect(resultado.errosMedidas[0], isNotNull);
    });
  });
}
