import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_receitas/model/repositorios/banco_dados.dart';
import 'package:app_receitas/model/repositorios/repositorio_receitas.dart';
import 'package:app_receitas/model/repositorios/repositorio_favoritos.dart';
import 'package:app_receitas/model/repositorios/repositorio_preparos.dart';
import 'package:app_receitas/model/servicos/tradutor_themealdb.dart';
import 'package:app_receitas/model/servicos/rascunho_receita.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  final banco = BancoDados.instancia;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('receitas_ext_test_');
    dbPath = '${tempDir.path}/test_receitas_ext.db';
    banco.customFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await banco.fechar();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
    RepositorioReceitas.limparMemoriaReceitasExternas();
    RepositorioFavoritos.limparMemoria();
    RepositorioPreparos.limparMemoriaWeb();
  });

  FichaTheMealDb criarFichaExemplo({
    String idMeal = '52772',
    String strMeal = 'Teriyaki Chicken Casserole',
    String categoria = 'Chicken',
    String? fotoRemota = 'https://www.themealdb.com/images/media/meals/wvpsxx1468256321.jpg',
    String instrucoes = 'Preheat oven to 350 F. Mix ingredients and bake.',
    List<ItemFichaExterna>? ingredientes,
  }) {
    return FichaTheMealDb(
      idMeal: idMeal,
      strMeal: strMeal,
      categoria: categoria,
      fotoRemota: fotoRemota,
      instrucoes: instrucoes,
      ingredientes: ingredientes ??
          const [
            ItemFichaExterna(ordem: 1, nome: 'soy sauce', medida: '3/4 cup'),
            ItemFichaExterna(ordem: 2, nome: 'water', medida: '1/2 cup'),
            ItemFichaExterna(ordem: 3, nome: 'brown sugar', medida: '1/4 cup'),
            ItemFichaExterna(ordem: 4, nome: 'chicken breasts', medida: '2 pounds'),
          ],
    );
  }

  group('2.1 Migração SQLite v1 -> v2 e tabela receita_externa_usuario', () {
    test('Nova instalação cria receita_externa_usuario com chave primária composta', () async {
      final db = await banco.inicializar(customPath: dbPath);
      expect(db, isNotNull);

      final tables = await db!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = 'receita_externa_usuario';",
      );
      expect(tables.isNotEmpty, isTrue);

      final pragma = await db.rawQuery("PRAGMA table_info('receita_externa_usuario');");
      final colunas = pragma.map((c) => c['name'] as String).toSet();
      expect(colunas, containsAll({'id_usuario', 'id_receita', 'salvo_em'}));
    });

    test('Migração de v1 populado para v2 preserva receitas, favoritos e preparos íntegros', () async {
      // 1. Cria manualmente um banco na versão 1 com dados populados
      final factory = databaseFactoryFfi;
      final dbV1 = await factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('PRAGMA foreign_keys = ON;');
            await db.execute('''
              CREATE TABLE configuracao_local (
                chave TEXT PRIMARY KEY,
                valor TEXT NOT NULL
              );
            ''');
            await db.execute('''
              CREATE TABLE usuario (
                id_usuario TEXT PRIMARY KEY,
                nome_exibicao TEXT NOT NULL,
                email TEXT UNIQUE,
                perfil TEXT NOT NULL CHECK(perfil IN ('usuario', 'administrador'))
              );
            ''');
            await db.execute('''
              CREATE TABLE receita (
                id_receita TEXT PRIMARY KEY,
                id_autor TEXT,
                origem TEXT NOT NULL CHECK (origem IN ('usuario', 'themealdb')),
                id_themealdb TEXT UNIQUE,
                visibilidade TEXT NOT NULL DEFAULT 'privada' CHECK (visibilidade IN ('privada', 'publica')),
                estado_moderacao TEXT NOT NULL DEFAULT 'liberada' CHECK (estado_moderacao IN ('pendente', 'liberada', 'rejeitada')),
                excluida_em TEXT,
                FOREIGN KEY (id_autor) REFERENCES usuario (id_usuario) ON DELETE CASCADE,
                CHECK ((origem = 'usuario' AND id_autor IS NOT NULL) OR (origem = 'themealdb' AND id_themealdb IS NOT NULL))
              );
            ''');
            await db.execute('''
              CREATE TABLE versao_receita (
                id_versao TEXT PRIMARY KEY,
                id_receita TEXT NOT NULL,
                numero_versao INTEGER NOT NULL,
                titulo TEXT NOT NULL,
                categoria TEXT NOT NULL,
                foto_local TEXT,
                foto_remota TEXT,
                FOREIGN KEY (id_receita) REFERENCES receita (id_receita) ON DELETE CASCADE,
                UNIQUE (id_receita, numero_versao)
              );
            ''');
            await db.execute('''
              CREATE TABLE ingrediente (
                id_ingrediente TEXT PRIMARY KEY,
                nome TEXT NOT NULL,
                nome_normalizado TEXT NOT NULL UNIQUE
              );
            ''');
            await db.execute('''
              CREATE TABLE item_receita (
                id_item TEXT PRIMARY KEY,
                id_versao TEXT NOT NULL,
                id_ingrediente TEXT NOT NULL,
                ordem INTEGER NOT NULL,
                medida TEXT NOT NULL,
                FOREIGN KEY (id_versao) REFERENCES versao_receita (id_versao) ON DELETE CASCADE,
                FOREIGN KEY (id_ingrediente) REFERENCES ingrediente (id_ingrediente) ON DELETE RESTRICT,
                UNIQUE (id_versao, ordem)
              );
            ''');
            await db.execute('''
              CREATE TABLE etapa (
                id_etapa TEXT PRIMARY KEY,
                id_versao TEXT NOT NULL,
                ordem INTEGER NOT NULL,
                instrucao TEXT NOT NULL,
                FOREIGN KEY (id_versao) REFERENCES versao_receita (id_versao) ON DELETE CASCADE,
                UNIQUE (id_versao, ordem)
              );
            ''');
            await db.execute('''
              CREATE TABLE favorito (
                id_usuario TEXT NOT NULL,
                id_receita TEXT NOT NULL,
                salvo_em TEXT NOT NULL,
                PRIMARY KEY (id_usuario, id_receita),
                FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE,
                FOREIGN KEY (id_receita) REFERENCES receita (id_receita) ON DELETE CASCADE
              );
            ''');
            await db.execute('''
              CREATE TABLE preparo (
                id_preparo TEXT PRIMARY KEY,
                id_usuario TEXT NOT NULL,
                id_versao TEXT NOT NULL,
                iniciado_em TEXT NOT NULL,
                concluido_em TEXT,
                ordem_etapa_atual INTEGER NOT NULL DEFAULT 1,
                FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE,
                FOREIGN KEY (id_versao) REFERENCES versao_receita (id_versao) ON DELETE RESTRICT
              );
            ''');
            await db.execute('''
              CREATE TABLE conferencia (
                id_preparo TEXT NOT NULL,
                id_item TEXT NOT NULL,
                estado TEXT NOT NULL DEFAULT 'nao_conferido' CHECK (estado IN ('nao_conferido', 'tenho', 'falta')),
                PRIMARY KEY (id_preparo, id_item),
                FOREIGN KEY (id_preparo) REFERENCES preparo (id_preparo) ON DELETE CASCADE,
                FOREIGN KEY (id_item) REFERENCES item_receita (id_item) ON DELETE RESTRICT
              );
            ''');
            await db.execute('''
              CREATE TABLE avaliacao (
                id_preparo TEXT PRIMARY KEY,
                estrelas INTEGER NOT NULL CHECK (estrelas >= 1 AND estrelas <= 5),
                visibilidade TEXT NOT NULL DEFAULT 'privada' CHECK (visibilidade IN ('privada', 'publica')),
                estado_moderacao TEXT NOT NULL DEFAULT 'liberada' CHECK (estado_moderacao IN ('pendente', 'liberada', 'rejeitada')),
                avaliadaEm TEXT NOT NULL,
                FOREIGN KEY (id_preparo) REFERENCES preparo (id_preparo) ON DELETE CASCADE
              );
            ''');
          },
        ),
      );

      // Popula dados no v1
      final agora = DateTime.now().toUtc().toIso8601String();
      await dbV1.insert('usuario', {'id_usuario': 'usr-v1', 'nome_exibicao': 'Usuário V1', 'perfil': 'usuario'});
      await dbV1.insert('receita', {
        'id_receita': 'rec-v1',
        'id_autor': 'usr-v1',
        'origem': 'usuario',
        'visibilidade': 'privada',
        'estado_moderacao': 'liberada',
      });
      await dbV1.insert('versao_receita', {
        'id_versao': 'ver-v1',
        'id_receita': 'rec-v1',
        'numero_versao': 1,
        'titulo': 'Bolo V1',
        'categoria': 'Sobremesa',
      });
      await dbV1.insert('favorito', {
        'id_usuario': 'usr-v1',
        'id_receita': 'rec-v1',
        'salvo_em': agora,
      });
      await dbV1.insert('preparo', {
        'id_preparo': 'prep-v1',
        'id_usuario': 'usr-v1',
        'id_versao': 'ver-v1',
        'iniciado_em': agora,
        'ordem_etapa_atual': 1,
      });
      await dbV1.close();

      // 2. Abre usando o BancoDados do app (versão 2)
      final dbV2 = await banco.inicializar(customPath: dbPath);
      expect(dbV2, isNotNull);

      final versaoDb = await dbV2!.getVersion();
      expect(versaoDb, equals(2));

      // 3. Valida integridade dos dados anteriores
      final recRows = await dbV2.query('receita', where: 'id_receita = ?', whereArgs: ['rec-v1']);
      expect(recRows.length, equals(1));
      expect(recRows.first['id_autor'], equals('usr-v1'));

      final favRows = await dbV2.query('favorito', where: 'id_receita = ?', whereArgs: ['rec-v1']);
      expect(favRows.length, equals(1));

      final prepRows = await dbV2.query('preparo', where: 'id_preparo = ?', whereArgs: ['prep-v1']);
      expect(prepRows.length, equals(1));

      // 4. Valida existência da tabela nova
      final extTable = await dbV2.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = 'receita_externa_usuario';",
      );
      expect(extTable.isNotEmpty, isTrue);
    });
  });

  group('2.2 Gravação transacional da cópia e deduplicação', () {
    test('Salva cópia externa transacionalmente e associa ao usuário', () async {
      await banco.inicializar(customPath: dbPath);
      final repo = RepositorioReceitas(bancoDados: banco);
      final usr = await banco.obterOuCriarUsuarioProvisorio();

      final ficha = criarFichaExemplo();
      final copia = await repo.salvarCopiaExterna(idUsuario: usr.idUsuario, ficha: ficha);

      expect(copia.receita.origem, equals('themealdb'));
      expect(copia.receita.idThemealdb, equals('52772'));
      expect(copia.versao.titulo, equals('Teriyaki Chicken Casserole'));
      expect(copia.versao.categoria, equals('Chicken'));
      expect(copia.itens.length, equals(4));
      expect(copia.etapas.length, equals(1));
      expect(copia.etapas.first.instrucao, contains('Preheat oven to 350 F'));

      // Repetição pelo mesmo usuário não duplica registro em receita nem em receita_externa_usuario
      final copia2 = await repo.salvarCopiaExterna(idUsuario: usr.idUsuario, ficha: ficha);
      expect(copia2.receita.idReceita, equals(copia.receita.idReceita));
      expect(copia2.versao.numeroVersao, equals(1));

      final salvas = await repo.listarReceitasExternasSalvas(usr.idUsuario);
      expect(salvas.length, equals(1));
    });

    test('Dois usuários salvando o mesmo idMeal compartilham id_receita mas têm associações separadas', () async {
      await banco.inicializar(customPath: dbPath);
      final repo = RepositorioReceitas(bancoDados: banco);

      final db = banco.database!;
      await db.insert('usuario', {'id_usuario': 'usr-A', 'nome_exibicao': 'Usuário A', 'perfil': 'usuario'});
      await db.insert('usuario', {'id_usuario': 'usr-B', 'nome_exibicao': 'Usuário B', 'perfil': 'usuario'});

      final ficha = criarFichaExemplo();
      final copiaA = await repo.salvarCopiaExterna(idUsuario: 'usr-A', ficha: ficha);
      final copiaB = await repo.salvarCopiaExterna(idUsuario: 'usr-B', ficha: ficha);

      expect(copiaA.receita.idReceita, equals(copiaB.receita.idReceita));

      final salvasA = await repo.listarReceitasExternasSalvas('usr-A');
      final salvasB = await repo.listarReceitasExternasSalvas('usr-B');
      expect(salvasA.length, equals(1));
      expect(salvasB.length, equals(1));
      expect(salvasA.first.idReceita, equals(salvasB.first.idReceita));
    });
  });

  group('2.3 Versionamento de cópias externas e preparos anteriores', () {
    test('Atualização externa com conteúdo idêntico mantém versão 1', () async {
      await banco.inicializar(customPath: dbPath);
      final repo = RepositorioReceitas(bancoDados: banco);
      final usr = await banco.obterOuCriarUsuarioProvisorio();

      final ficha1 = criarFichaExemplo();
      await repo.salvarCopiaExterna(idUsuario: usr.idUsuario, ficha: ficha1);

      final fichaIdentica = criarFichaExemplo();
      final copia2 = await repo.salvarCopiaExterna(idUsuario: usr.idUsuario, ficha: fichaIdentica);
      expect(copia2.versao.numeroVersao, equals(1));
    });

    test('Conteúdo alterado gera versão 2 e preserva preparo anterior na versão 1', () async {
      await banco.inicializar(customPath: dbPath);
      final repoReceitas = RepositorioReceitas(bancoDados: banco);
      final repoPreparos = RepositorioPreparos(bancoDados: banco);
      final usr = await banco.obterOuCriarUsuarioProvisorio();

      // 1. Salva versão 1
      final ficha1 = criarFichaExemplo(instrucoes: 'Instrução original v1');
      final copiaV1 = await repoReceitas.salvarCopiaExterna(idUsuario: usr.idUsuario, ficha: ficha1);
      expect(copiaV1.versao.numeroVersao, equals(1));

      // 2. Inicia preparo na versão 1
      final preparo = await repoPreparos.iniciarPreparo(
        idUsuario: usr.idUsuario,
        idReceita: copiaV1.receita.idReceita,
      );
      expect(preparo.versao.numeroVersao, equals(1));
      expect(preparo.etapas.first.instrucao, equals('Instrução original v1'));

      // 3. Salva atualização com nova instrução -> gera versão 2
      final ficha2 = criarFichaExemplo(instrucoes: 'Instrução modificada v2 com mais detalhes');
      final copiaV2 = await repoReceitas.salvarCopiaExterna(idUsuario: usr.idUsuario, ficha: ficha2);
      expect(copiaV2.versao.numeroVersao, equals(2));

      // 4. Verifica que o preparo iniciado anteriormente ainda aponta para a versão 1
      final preparoRecarregado = await repoPreparos.obterPreparoDetalhado(
        idPreparo: preparo.preparo.idPreparo,
        idUsuario: usr.idUsuario,
      );
      expect(preparoRecarregado, isNotNull);
      expect(preparoRecarregado!.versao.numeroVersao, equals(1));
      expect(preparoRecarregado.etapas.first.instrucao, equals('Instrução original v1'));

      // 5. A receita por ID retorna a versão mais recente (v2)
      final receitaRecente = await repoReceitas.obterReceitaPorId(
        idReceita: copiaV1.receita.idReceita,
        idUsuario: usr.idUsuario,
      );
      expect(receitaRecente, isNotNull);
      expect(receitaRecente!.versao.numeroVersao, equals(2));
      expect(receitaRecente.etapas.first.instrucao, contains('v2'));
    });
  });

  group('2.4 & 3.1 Isolamento de contas, consulta e Minhas Receitas', () {
    test('Minhas receitas exibe apenas receitas próprias do autor e exclui externas salvas', () async {
      await banco.inicializar(customPath: dbPath);
      final repo = RepositorioReceitas(bancoDados: banco);
      final usr = await banco.obterOuCriarUsuarioProvisorio();

      // Cria receita própria
      await repo.criarReceitaPropria(
        idAutor: usr.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Minha Panqueca',
          categoria: 'Café',
          etapas: ['Bata tudo', 'Frite'],
          itens: [
            RascunhoItemReceita(nomeIngrediente: 'Farinha', medida: '1 xícara'),
          ],
        ),
      );

      // Salva receita externa
      final ficha = criarFichaExemplo();
      await repo.salvarCopiaExterna(idUsuario: usr.idUsuario, ficha: ficha);

      // Listagem de Minhas Receitas (próprias)
      final proprias = await repo.listarReceitasProprias(usr.idUsuario);
      expect(proprias.length, equals(1));
      expect(proprias.first.titulo, equals('Minha Panqueca'));

      // Listagem de Receitas Externas Salvas
      final externas = await repo.listarReceitasExternasSalvas(usr.idUsuario);
      expect(externas.length, equals(1));
      expect(externas.first.titulo, equals('Teriyaki Chicken Casserole'));
    });

    test('Usuário B não consegue abrir pelo ID uma cópia externa associada apenas ao Usuário A', () async {
      await banco.inicializar(customPath: dbPath);
      final repo = RepositorioReceitas(bancoDados: banco);

      final db = banco.database!;
      await db.insert('usuario', {'id_usuario': 'usr-A', 'nome_exibicao': 'Usuário A', 'perfil': 'usuario'});
      await db.insert('usuario', {'id_usuario': 'usr-B', 'nome_exibicao': 'Usuário B', 'perfil': 'usuario'});

      final ficha = criarFichaExemplo();
      final copiaA = await repo.salvarCopiaExterna(idUsuario: 'usr-A', ficha: ficha);

      // Usuário A consegue abrir
      final recA = await repo.obterReceitaPorId(idReceita: copiaA.receita.idReceita, idUsuario: 'usr-A');
      expect(recA, isNotNull);

      // Usuário B NÃO consegue abrir
      final recB = await repo.obterReceitaPorId(idReceita: copiaA.receita.idReceita, idUsuario: 'usr-B');
      expect(recB, isNull);
    });

    test('Fallback em memória suporta isolamento e listagem de salvas', () async {
      final repo = RepositorioReceitas(forcarMemoria: true);

      final ficha = criarFichaExemplo();
      final copia = await repo.salvarCopiaExterna(idUsuario: 'usr-mem-A', ficha: ficha);

      final salvasA = await repo.listarReceitasExternasSalvas('usr-mem-A');
      expect(salvasA.length, equals(1));

      final salvasB = await repo.listarReceitasExternasSalvas('usr-mem-B');
      expect(salvasB.isEmpty, isTrue);

      final recA = await repo.obterReceitaPorId(idReceita: copia.receita.idReceita, idUsuario: 'usr-mem-A');
      expect(recA, isNotNull);

      final recB = await repo.obterReceitaPorId(idReceita: copia.receita.idReceita, idUsuario: 'usr-mem-B');
      expect(recB, isNull);
    });
  });

  group('3.2 RepositorioFavoritos e ControllerFavoritos com externas', () {
    test('Adiciona favorito de receita externa copiada e lista na aba mista', () async {
      await banco.inicializar(customPath: dbPath);
      final repoReceitas = RepositorioReceitas(bancoDados: banco);
      final repoFavoritos = RepositorioFavoritos(bancoDados: banco);
      final usr = await banco.obterOuCriarUsuarioProvisorio();

      // 1. Cria receita própria favoritada
      final recPropria = await repoReceitas.criarReceitaPropria(
        idAutor: usr.idUsuario,
        rascunho: const RascunhoReceita(
          titulo: 'Waffles Caseiros',
          categoria: 'Café',
          etapas: ['Misture e asse'],
          itens: [RascunhoItemReceita(nomeIngrediente: 'Ovo', medida: '2 unidades')],
        ),
      );
      await repoFavoritos.adicionarFavorito(idUsuario: usr.idUsuario, idReceita: recPropria.receita.idReceita);

      // 2. Salva receita externa e favorita
      final ficha = criarFichaExemplo();
      final copiaExt = await repoReceitas.salvarCopiaExterna(idUsuario: usr.idUsuario, ficha: ficha);
      await repoFavoritos.adicionarFavorito(idUsuario: usr.idUsuario, idReceita: copiaExt.receita.idReceita);

      // 3. Lista favoritos mista
      final favs = await repoFavoritos.listarFavoritos(usr.idUsuario);
      expect(favs.length, equals(2));
      final origens = favs.map((f) => f.origem).toSet();
      expect(origens, containsAll({'usuario', 'themealdb'}));

      // Desfavoritar externa não remove o preparo anterior
      final repoPreparos = RepositorioPreparos(bancoDados: banco);
      final prep = await repoPreparos.iniciarPreparo(idUsuario: usr.idUsuario, idReceita: copiaExt.receita.idReceita);
      await repoPreparos.concluirPreparo(idPreparo: prep.preparo.idPreparo, idUsuario: usr.idUsuario);

      await repoFavoritos.removerFavorito(idUsuario: usr.idUsuario, idReceita: copiaExt.receita.idReceita);
      final favsAposRemover = await repoFavoritos.listarFavoritos(usr.idUsuario);
      expect(favsAposRemover.length, equals(1));
      expect(favsAposRemover.first.idReceita, equals(recPropria.receita.idReceita));

      final concluidos = await repoPreparos.listarPreparosConcluidos(idUsuario: usr.idUsuario);
      expect(concluidos.length, equals(1));
      expect(concluidos.first.idReceita, equals(copiaExt.receita.idReceita));
    });
  });

  group('3.3 RepositorioPreparos com receitas externas copiadas', () {
    test('Inicia preparo de receita externa, preenche checklist e conclui offline', () async {
      await banco.inicializar(customPath: dbPath);
      final repoReceitas = RepositorioReceitas(bancoDados: banco);
      final repoPreparos = RepositorioPreparos(bancoDados: banco);
      final usr = await banco.obterOuCriarUsuarioProvisorio();

      final ficha = criarFichaExemplo();
      final copia = await repoReceitas.salvarCopiaExterna(idUsuario: usr.idUsuario, ficha: ficha);

      final preparo = await repoPreparos.iniciarPreparo(
        idUsuario: usr.idUsuario,
        idReceita: copia.receita.idReceita,
      );
      expect(preparo.conferencias.length, equals(4));
      expect(preparo.etapas.length, equals(1));

      // Atualiza checklist
      await repoPreparos.atualizarConferencia(
        idPreparo: preparo.preparo.idPreparo,
        idItem: preparo.conferencias.first.idItem,
        novoEstado: 'tenho',
        idUsuario: usr.idUsuario,
      );

      // Conclui preparo
      final concluidoEm = await repoPreparos.concluirPreparo(
        idPreparo: preparo.preparo.idPreparo,
        idUsuario: usr.idUsuario,
      );
      expect(concluidoEm, isNotNull);

      final historico = await repoPreparos.listarPreparosConcluidos(idUsuario: usr.idUsuario);
      expect(historico.length, equals(1));
      expect(historico.first.tituloReceita, equals('Teriyaki Chicken Casserole'));
    });

    test('Bloqueia início de preparo de receita externa não associada ao usuário', () async {
      await banco.inicializar(customPath: dbPath);
      final repoReceitas = RepositorioReceitas(bancoDados: banco);
      final repoPreparos = RepositorioPreparos(bancoDados: banco);

      final db = banco.database!;
      await db.insert('usuario', {'id_usuario': 'usr-dono', 'nome_exibicao': 'Dono', 'perfil': 'usuario'});
      await db.insert('usuario', {'id_usuario': 'usr-invasor', 'nome_exibicao': 'Invasor', 'perfil': 'usuario'});

      final ficha = criarFichaExemplo();
      final copia = await repoReceitas.salvarCopiaExterna(idUsuario: 'usr-dono', ficha: ficha);

      // Invasor tenta iniciar preparo da cópia alheia
      expect(
        () => repoPreparos.iniciarPreparo(
          idUsuario: 'usr-invasor',
          idReceita: copia.receita.idReceita,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
