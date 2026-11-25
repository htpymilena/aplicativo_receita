import 'package:flutter_test/flutter_test.dart';
import 'package:app_receitas/model/servicos/servico_traducao.dart';
import 'package:app_receitas/model/servicos/tradutor_themealdb.dart';

void main() {
  late ServicoTraducao servico;

  setUp(() {
    servico = ServicoTraducao();
  });

  group('ServicoTraducao - Dicionário, Categorias e Fallback', () {
    test('Converte categorias oficiais do TheMealDB de inglês para português', () {
      expect(servico.categoriaParaPortugues('Chicken'), equals('Frango'));
      expect(servico.categoriaParaPortugues('Seafood'), equals('Frutos do Mar'));
      expect(servico.categoriaParaPortugues('Dessert'), equals('Sobremesa'));
      expect(servico.categoriaParaPortugues('Beef'), equals('Carne Bovina'));
      expect(servico.categoriaParaPortugues('Vegetarian'), equals('Vegetariano'));
      expect(servico.categoriaParaPortugues('UnknownCategory'), equals('UnknownCategory'));
    });

    test('Converte categorias em português para o inglês do TheMealDB', () {
      expect(servico.categoriaParaIngles('Frango'), equals('Chicken'));
      expect(servico.categoriaParaIngles('Frutos do Mar'), equals('Seafood'));
      expect(servico.categoriaParaIngles('Sobremesa'), equals('Dessert'));
      expect(servico.categoriaParaIngles('Carne Bovina'), equals('Beef'));
      expect(servico.categoriaParaIngles('Carne'), equals('Beef'));
      expect(servico.categoriaParaIngles('Vegetariano'), equals('Vegetarian'));
      expect(servico.categoriaParaIngles('Desconhecida'), equals('Desconhecida'));
    });

    test('Traduz termos culinários rápidos instantaneamente sem internet', () async {
      final t1 = await servico.termoBuscaParaIngles('frango');
      expect(t1.toLowerCase(), equals('chicken'));

      final t2 = await servico.termoBuscaParaIngles('alho');
      expect(t2.toLowerCase(), equals('garlic'));

      final t3 = await servico.termoBuscaParaIngles('batata');
      expect(t3, equals('potato'));

      final t4 = await servico.termoBuscaParaIngles('sobremesa');
      expect(t4, equals('Dessert'));

      final vazio = await servico.termoBuscaParaIngles('   ');
      expect(vazio, equals(''));
    });

    test('Traduz ficha mantendo estrutura e fallback seguro', () async {
      const fichaOriginal = FichaTheMealDb(
        idMeal: '99999',
        strMeal: 'Chicken and Rice',
        categoria: 'Chicken',
        fotoRemota: 'http://foto.jpg',
        instrucoes: 'Cook well',
        ingredientes: [
          ItemFichaExterna(ordem: 1, nome: 'Rice', medida: '1 cup'),
        ],
      );

      final fichaTraduzida = await servico.traduzirFichaParaPortugues(fichaOriginal);

      expect(fichaTraduzida.idMeal, equals('99999'));
      expect(fichaTraduzida.categoria, equals('Frango'));
      expect(fichaTraduzida.fotoRemota, equals('http://foto.jpg'));
      expect(fichaTraduzida.ingredientes.length, equals(1));
      expect(fichaTraduzida.ingredientes.first.ordem, equals(1));
    });
  });
}
