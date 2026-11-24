import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_receitas/model/entidades/entidades.dart';
import 'package:app_receitas/model/repositorios/banco_dados.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  final banco = BancoDados.instancia;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('receitas_db_test_');
    dbPath = '${tempDir.path}/test_receitas.db';
    banco.customFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await banco.fechar();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('BancoDados SQLite v1 - Esquema, Restrições e Ciclo de Vida', () {
    test('1.2 Abertura do SQLite cria as 10 tabelas e PRAGMA foreign_keys = ON', () async {
      final db = await banco.inicializar(customPath: dbPath);
      expect(db, isNotNull);
      expect(db!.isOpen, isTrue);

      final fkResult = await db.rawQuery('PRAGMA foreign_keys;');
      expect(fkResult.first.values.first, equals(1));

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';",
      );
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      final expectedTables = {
        'configuracao_local',
        'usuario',
        'receita',
        'versao_receita',
        'ingrediente',
        'item_receita',
        'etapa',
        'favorito',
        'preparo',
        'conferencia',
        'avaliacao',
      };
      expect(tableNames, containsAll(expectedTables));

      // Rejeição de FK inexistente
      expect(
        () async => await db.insert('receita', {
          'id_receita': 'rec-invalida',
          'id_autor': 'usr-nao-existe',
          'origem': 'usuario',
          'visibilidade': 'privada',
          'estado_moderacao': 'liberada',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('1.3 CHECKs, domínios, unicidade e triggers de coerência', () async {
      final db = (await banco.inicializar(customPath: dbPath))!;
      final usuario = await banco.obterOuCriarUsuarioProvisorio();

      // Email único
      await db.insert('usuario', {
        'id_usuario': 'usr-unico-1',
        'nome_exibicao': 'User 1',
        'email': 'repetido@teste.com',
        'perfil': 'usuario',
      });
      expect(
        () async => await db.insert('usuario', {
          'id_usuario': 'usr-unico-2',
          'nome_exibicao': 'User 2',
          'email': 'repetido@teste.com',
          'perfil': 'usuario',
        }),
        throwsA(isA<DatabaseException>()),
      );

      // Origem usuario sem id_autor deve falhar
      expect(
        () async => await db.insert('receita', {
          'id_receita': 'rec-sem-autor',
          'id_autor': null,
          'origem': 'usuario',
          'visibilidade': 'privada',
          'estado_moderacao': 'liberada',
        }),
        throwsA(isA<DatabaseException>()),
      );

      // Inserção de receita válida
      const receita = Receita(
        idReceita: 'rec-1',
        idAutor: null,
        origem: 'themealdb',
        idThemealdb: '7788',
      );
      await db.insert('receita', receita.toMap());

      // Versão 1 com etapa
      await db.insert('versao_receita', {
        'id_versao': 'ver-1',
        'id_receita': 'rec-1',
        'numero_versao': 1,
        'titulo': 'Receita de Teste',
        'categoria': 'Almoço',
      });

      // Etapa 1
      await db.insert('etapa', {
        'id_etapa': 'etp-1',
        'id_versao': 'ver-1',
        'ordem': 1,
        'instrucao': 'Primeiro passo',
      });

      // Ingrediente e Item
      await db.insert('ingrediente', {
        'id_ingrediente': 'ing-1',
        'nome': 'Sal',
        'nome_normalizado': 'sal',
      });
      await db.insert('item_receita', {
        'id_item': 'itm-1',
        'id_versao': 'ver-1',
        'id_ingrediente': 'ing-1',
        'ordem': 1,
        'medida': '1 pitada',
      });

      // Versão 2 para testar trigger de versão divergente
      await db.insert('versao_receita', {
        'id_versao': 'ver-2',
        'id_receita': 'rec-1',
        'numero_versao': 2,
        'titulo': 'Receita v2',
        'categoria': 'Almoço',
      });
      await db.insert('item_receita', {
        'id_item': 'itm-2-v2',
        'id_versao': 'ver-2',
        'id_ingrediente': 'ing-1',
        'ordem': 1,
        'medida': '2 pitadas',
      });

      // Preparo na versão 1
      await db.insert('preparo', {
        'id_preparo': 'prep-1',
        'id_usuario': usuario.idUsuario,
        'id_versao': 'ver-1',
        'iniciado_em': DateTime.now().toUtc().toIso8601String(),
        'ordem_etapa_atual': 1,
      });

      // Conferencia apontando para itm-2-v2 (que pertence à ver-2) DEVE falhar pelo trigger
      expect(
        () async => await db.insert('conferencia', {
          'id_preparo': 'prep-1',
          'id_item': 'itm-2-v2',
          'estado': 'nao_conferido',
        }),
        throwsA(isA<DatabaseException>()),
      );

      // Conferencia válida com itm-1 (pertence à ver-1)
      await db.insert('conferencia', {
        'id_preparo': 'prep-1',
        'id_item': 'itm-1',
        'estado': 'nao_conferido',
      });

      // Avaliação com estrelas fora do domínio 1..5 deve falhar
      expect(
        () async => await db.insert('avaliacao', {
          'id_preparo': 'prep-1',
          'estrelas': 6,
          'visibilidade': 'privada',
          'estado_moderacao': 'liberada',
          'avaliada_em': DateTime.now().toUtc().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );

      // Avaliação válida
      await db.insert('avaliacao', {
        'id_preparo': 'prep-1',
        'estrelas': 5,
        'visibilidade': 'privada',
        'estado_moderacao': 'liberada',
        'avaliada_em': DateTime.now().toUtc().toIso8601String(),
      });

      // Segunda avaliação no mesmo preparo deve falhar (PK id_preparo)
      expect(
        () async => await db.insert('avaliacao', {
          'id_preparo': 'prep-1',
          'estrelas': 4,
          'visibilidade': 'privada',
          'estado_moderacao': 'liberada',
          'avaliada_em': DateTime.now().toUtc().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('2.1 Identidade provisória estável e única', () async {
      await banco.inicializar(customPath: dbPath);
      final u1 = await banco.obterOuCriarUsuarioProvisorio();
      expect(u1.idUsuario, isNotEmpty);
      expect(u1.email, isNull);

      // Segunda chamada deve retornar o mesmo ID
      final u2 = await banco.obterOuCriarUsuarioProvisorio();
      expect(u2.idUsuario, equals(u1.idUsuario));

      // Fechar e reabrir conexão
      await banco.fechar();
      await banco.inicializar(customPath: dbPath);
      final u3 = await banco.obterOuCriarUsuarioProvisorio();
      expect(u3.idUsuario, equals(u1.idUsuario));

      // Conferir que existe apenas uma única linha de usuário
      final count = await banco.database!.rawQuery('SELECT count(*) as total FROM usuario');
      expect(count.first['total'], equals(1));
    });

    test('1.4 & 2.3 Ritual abrir -> gravar -> fechar -> reabrir -> ler persiste dados e versão', () async {
      // 1. Abrir
      var db = (await banco.inicializar(customPath: dbPath))!;
      final usuario = await banco.obterOuCriarUsuarioProvisorio();

      // 2. Gravar fixture válida
      const receita = Receita(
        idReceita: 'rec-persistente',
        idAutor: null,
        origem: 'themealdb',
        idThemealdb: '99001',
      );
      await db.insert('receita', receita.toMap());

      await db.insert('favorito', {
        'id_usuario': usuario.idUsuario,
        'id_receita': receita.idReceita,
        'salvo_em': '2026-11-23T12:00:00.000Z',
      });

      // 3. Fechar
      await banco.fechar();

      // 4. Reabrir
      db = (await banco.inicializar(customPath: dbPath))!;

      // 5. Ler e conferir dados e versão
      final versionResult = await db.rawQuery('PRAGMA user_version;');
      expect(versionResult.first['user_version'], equals(1));

      final receitasLidas = await db.query(
        'receita',
        where: 'id_receita = ?',
        whereArgs: ['rec-persistente'],
      );
      expect(receitasLidas.length, equals(1));
      expect(receitasLidas.first['id_theme_aldb'] ?? receitasLidas.first['id_themealdb'], equals('99001'));

      final favoritosLidos = await db.query(
        'favorito',
        where: 'id_usuario = ? AND id_receita = ?',
        whereArgs: [usuario.idUsuario, 'rec-persistente'],
      );
      expect(favoritosLidos.length, equals(1));
    });
  });
}
