import 'package:flutter_test/flutter_test.dart';
import 'package:app_receitas/model/entidades/entidades.dart';

void main() {
  group('Serialização e desserialização das 10 entidades do MER', () {
    test('Usuario - round-trip com email preenchido e nulo', () {
      final u1 = Usuario(
        idUsuario: 'usr-1',
        nomeExibicao: 'Chefe Silva',
        email: 'chefe@exemplo.com',
        perfil: 'administrador',
      );
      final m1 = u1.toMap();
      expect(Usuario.fromMap(m1), equals(u1));

      final u2 = Usuario(
        idUsuario: 'usr-2',
        nomeExibicao: 'Cozinheiro Provisório',
        email: null,
        perfil: 'usuario',
      );
      final m2 = u2.toMap();
      expect(m2['email'], isNull);
      expect(Usuario.fromMap(m2), equals(u2));
    });

    test('Receita - round-trip com campos opcionais preenchidos e nulos', () {
      final now = DateTime.utc(2026, 11, 23, 12, 0, 0);
      final r1 = Receita(
        idReceita: 'rec-1',
        idAutor: 'usr-1',
        origem: 'usuario',
        idThemealdb: null,
        visibilidade: 'publica',
        estadoModeracao: 'liberada',
        excluidaEm: null,
      );
      final m1 = r1.toMap();
      expect(Receita.fromMap(m1), equals(r1));

      final r2 = Receita(
        idReceita: 'rec-2',
        idAutor: null,
        origem: 'themealdb',
        idThemealdb: '52772',
        visibilidade: 'privada',
        estadoModeracao: 'oculta',
        excluidaEm: now,
      );
      final m2 = r2.toMap();
      expect(Receita.fromMap(m2), equals(r2));
    });

    test('VersaoReceita - round-trip com fotos e campos', () {
      final v1 = VersaoReceita(
        idVersao: 'ver-1',
        idReceita: 'rec-1',
        numeroVersao: 1,
        titulo: 'Panqueca de Banana',
        categoria: 'Café da Manhã',
        fotoLocal: '/path/to/foto.jpg',
        fotoRemota: null,
      );
      final m1 = v1.toMap();
      expect(VersaoReceita.fromMap(m1), equals(v1));

      final v2 = VersaoReceita(
        idVersao: 'ver-2',
        idReceita: 'rec-1',
        numeroVersao: 2,
        titulo: 'Panqueca de Banana com Canela',
        categoria: 'Café da Manhã',
        fotoLocal: null,
        fotoRemota: 'https://exemplo.com/foto.jpg',
      );
      final m2 = v2.toMap();
      expect(VersaoReceita.fromMap(m2), equals(v2));
    });

    test('Ingrediente - round-trip', () {
      final ing = Ingrediente(
        idIngrediente: 'ing-1',
        nome: 'Açúcar Cristal',
        nomeNormalizado: 'acucar cristal',
      );
      final m = ing.toMap();
      expect(Ingrediente.fromMap(m), equals(ing));
    });

    test('ItemReceita - round-trip', () {
      final item = ItemReceita(
        idItem: 'itm-1',
        idVersao: 'ver-1',
        idIngrediente: 'ing-1',
        ordem: 1,
        medida: '2 colheres de sopa',
      );
      final m = item.toMap();
      expect(ItemReceita.fromMap(m), equals(item));
    });

    test('Etapa - round-trip', () {
      final etapa = Etapa(
        idEtapa: 'etp-1',
        idVersao: 'ver-1',
        ordem: 1,
        instrucao: 'Misture os ingredientes em uma tigela grande.',
      );
      final m = etapa.toMap();
      expect(Etapa.fromMap(m), equals(etapa));
    });

    test('Favorito - round-trip', () {
      final now = DateTime.utc(2026, 11, 23, 10, 30, 0);
      final fav = Favorito(
        idUsuario: 'usr-1',
        idReceita: 'rec-1',
        salvoEm: now,
      );
      final m = fav.toMap();
      expect(Favorito.fromMap(m), equals(fav));
    });

    test('Preparo - round-trip com concluidoEm preenchido e nulo', () {
      final start = DateTime.utc(2026, 11, 23, 14, 0, 0);
      final end = DateTime.utc(2026, 11, 23, 14, 45, 0);

      final p1 = Preparo(
        idPreparo: 'prep-1',
        idUsuario: 'usr-1',
        idVersao: 'ver-1',
        iniciadoEm: start,
        concluidoEm: null,
        ordemEtapaAtual: 2,
      );
      expect(p1.emAndamento, isTrue);
      final m1 = p1.toMap();
      expect(Preparo.fromMap(m1), equals(p1));

      final p2 = Preparo(
        idPreparo: 'prep-2',
        idUsuario: 'usr-1',
        idVersao: 'ver-1',
        iniciadoEm: start,
        concluidoEm: end,
        ordemEtapaAtual: 3,
      );
      expect(p2.emAndamento, isFalse);
      final m2 = p2.toMap();
      expect(Preparo.fromMap(m2), equals(p2));
    });

    test('Conferencia - round-trip', () {
      final conf = Conferencia(
        idPreparo: 'prep-1',
        idItem: 'itm-1',
        estado: 'tenho',
      );
      final m = conf.toMap();
      expect(Conferencia.fromMap(m), equals(conf));
    });

    test('Avaliacao - round-trip com notas e visibilidades', () {
      final now = DateTime.utc(2026, 11, 23, 15, 0, 0);
      final aval = Avaliacao(
        idPreparo: 'prep-2',
        estrelas: 5,
        visibilidade: 'publica',
        estadoModeracao: 'liberada',
        avaliadaEm: now,
      );
      final m = aval.toMap();
      expect(Avaliacao.fromMap(m), equals(aval));
    });
  });
}
