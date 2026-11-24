import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../entidades/usuario.dart';

/// Gerenciador do banco de dados SQLite local do aplicativo.
class BancoDados {
  static const String nomeArquivo = 'app_receitas.db';
  static const int versaoAtual = 1;

  static final BancoDados instancia = BancoDados._interno();
  BancoDados._interno();

  Database? _db;
  DatabaseFactory? _customFactory;

  /// Permite injetar uma factory alternativa (por exemplo, `sqflite_common_ffi` para testes desktop).
  @visibleForTesting
  set customFactory(DatabaseFactory? factory) => _customFactory = factory;

  DatabaseFactory get _factory => _customFactory ?? databaseFactory;

  Database? get database => _db;

  /// Inicializa o banco de dados e garante a existência do usuário provisório.
  Future<Database?> inicializar({String? customPath}) async {
    if (kIsWeb && _customFactory == null) {
      // No ambiente web sem factory customizada, evita falha de sqflite não suportado.
      return null;
    }

    if (_db != null && _db!.isOpen) {
      return _db!;
    }

    final String caminhoBanco;
    if (customPath != null) {
      caminhoBanco = customPath;
    } else {
      final docsDir = await getApplicationDocumentsDirectory();
      caminhoBanco = p.join(docsDir.path, nomeArquivo);
    }

    _db = await _factory.openDatabase(
      caminhoBanco,
      options: OpenDatabaseOptions(
        version: versaoAtual,
        onConfigure: _aoConfigurar,
        onCreate: _aoCriar,
        onUpgrade: _aoAtualizar,
      ),
    );

    await obterOuCriarUsuarioProvisorio();
    return _db!;
  }

  /// Fecha a conexão atual do banco de dados.
  Future<void> fechar() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  /// Habilita verificação estrita de chaves estrangeiras em todas as conexões.
  static Future<void> _aoConfigurar(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  /// Cria o esquema versão 1 com as 10 tabelas do MER, restrições e triggers.
  static Future<void> _aoCriar(Database db, int versao) async {
    final batch = db.batch();

    // Tabela auxiliar para metadados locais (ex: id do usuário ativo provisório)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS configuracao_local (
        chave TEXT PRIMARY KEY,
        valor TEXT NOT NULL
      );
    ''');

    // 1. USUARIO
    batch.execute('''
      CREATE TABLE usuario (
        id_usuario TEXT PRIMARY KEY,
        nome_exibicao TEXT NOT NULL,
        email TEXT UNIQUE,
        perfil TEXT NOT NULL CHECK(perfil IN ('usuario', 'administrador'))
      );
    ''');

    // 2. RECEITA
    batch.execute('''
      CREATE TABLE receita (
        id_receita TEXT PRIMARY KEY,
        id_autor TEXT REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
        origem TEXT NOT NULL CHECK(origem IN ('usuario', 'themealdb')),
        id_themealdb TEXT UNIQUE,
        visibilidade TEXT NOT NULL DEFAULT 'privada' CHECK(visibilidade IN ('privada', 'publica')),
        estado_moderacao TEXT NOT NULL DEFAULT 'liberada' CHECK(estado_moderacao IN ('liberada', 'oculta', 'pendente')),
        excluida_em TEXT,
        CHECK(
          (origem = 'usuario' AND id_autor IS NOT NULL) OR
          (origem = 'themealdb' AND id_themealdb IS NOT NULL)
        )
      );
    ''');

    // 3. VERSAO_RECEITA
    batch.execute('''
      CREATE TABLE versao_receita (
        id_versao TEXT PRIMARY KEY,
        id_receita TEXT NOT NULL REFERENCES receita(id_receita) ON DELETE RESTRICT,
        numero_versao INTEGER NOT NULL CHECK(numero_versao >= 1),
        titulo TEXT NOT NULL,
        categoria TEXT NOT NULL,
        foto_local TEXT,
        foto_remota TEXT,
        UNIQUE(id_receita, numero_versao)
      );
    ''');

    // 4. INGREDIENTE
    batch.execute('''
      CREATE TABLE ingrediente (
        id_ingrediente TEXT PRIMARY KEY,
        nome TEXT NOT NULL,
        nome_normalizado TEXT NOT NULL UNIQUE
      );
    ''');

    // 5. ITEM_RECEITA
    batch.execute('''
      CREATE TABLE item_receita (
        id_item TEXT PRIMARY KEY,
        id_versao TEXT NOT NULL REFERENCES versao_receita(id_versao) ON DELETE RESTRICT,
        id_ingrediente TEXT NOT NULL REFERENCES ingrediente(id_ingrediente) ON DELETE RESTRICT,
        ordem INTEGER NOT NULL CHECK(ordem >= 1),
        medida TEXT NOT NULL,
        UNIQUE(id_versao, ordem)
      );
    ''');

    // 6. ETAPA
    batch.execute('''
      CREATE TABLE etapa (
        id_etapa TEXT PRIMARY KEY,
        id_versao TEXT NOT NULL REFERENCES versao_receita(id_versao) ON DELETE RESTRICT,
        ordem INTEGER NOT NULL CHECK(ordem >= 1),
        instrucao TEXT NOT NULL,
        UNIQUE(id_versao, ordem)
      );
    ''');

    // 7. FAVORITO
    batch.execute('''
      CREATE TABLE favorito (
        id_usuario TEXT NOT NULL REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
        id_receita TEXT NOT NULL REFERENCES receita(id_receita) ON DELETE RESTRICT,
        salvo_em TEXT NOT NULL,
        PRIMARY KEY (id_usuario, id_receita)
      );
    ''');

    // 8. PREPARO
    batch.execute('''
      CREATE TABLE preparo (
        id_preparo TEXT PRIMARY KEY,
        id_usuario TEXT NOT NULL REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
        id_versao TEXT NOT NULL REFERENCES versao_receita(id_versao) ON DELETE RESTRICT,
        iniciado_em TEXT NOT NULL,
        concluido_em TEXT,
        ordem_etapa_atual INTEGER NOT NULL DEFAULT 1 CHECK(ordem_etapa_atual >= 1)
      );
    ''');

    // 9. CONFERENCIA
    batch.execute('''
      CREATE TABLE conferencia (
        id_preparo TEXT NOT NULL REFERENCES preparo(id_preparo) ON DELETE RESTRICT,
        id_item TEXT NOT NULL REFERENCES item_receita(id_item) ON DELETE RESTRICT,
        estado TEXT NOT NULL DEFAULT 'nao_conferido' CHECK(estado IN ('nao_conferido', 'tenho', 'falta')),
        PRIMARY KEY (id_preparo, id_item)
      );
    ''');

    // 10. AVALIACAO
    batch.execute('''
      CREATE TABLE avaliacao (
        id_preparo TEXT PRIMARY KEY REFERENCES preparo(id_preparo) ON DELETE RESTRICT,
        estrelas INTEGER NOT NULL CHECK(estrelas BETWEEN 1 AND 5),
        visibilidade TEXT NOT NULL DEFAULT 'privada' CHECK(visibilidade IN ('privada', 'publica')),
        estado_moderacao TEXT NOT NULL DEFAULT 'liberada' CHECK(estado_moderacao IN ('liberada', 'oculta', 'pendente')),
        avaliada_em TEXT NOT NULL
      );
    ''');

    // Triggers para coerência entre conferência/item/versão e preparo/etapa/versão
    batch.execute('''
      CREATE TRIGGER trg_conferencia_versao_check_insert
      BEFORE INSERT ON conferencia
      BEGIN
        SELECT RAISE(ABORT, 'Item da conferencia nao pertence a versao do preparo')
        WHERE (
          SELECT v_prep.id_versao
          FROM preparo v_prep
          WHERE v_prep.id_preparo = NEW.id_preparo
        ) <> (
          SELECT itm.id_versao
          FROM item_receita itm
          WHERE itm.id_item = NEW.id_item
        );
      END;
    ''');

    batch.execute('''
      CREATE TRIGGER trg_conferencia_versao_check_update
      BEFORE UPDATE OF id_item, id_preparo ON conferencia
      BEGIN
        SELECT RAISE(ABORT, 'Item da conferencia nao pertence a versao do preparo')
        WHERE (
          SELECT v_prep.id_versao
          FROM preparo v_prep
          WHERE v_prep.id_preparo = NEW.id_preparo
        ) <> (
          SELECT itm.id_versao
          FROM item_receita itm
          WHERE itm.id_item = NEW.id_item
        );
      END;
    ''');

    batch.execute('''
      CREATE TRIGGER trg_preparo_etapa_atual_check_insert
      BEFORE INSERT ON preparo
      BEGIN
        SELECT RAISE(ABORT, 'ordem_etapa_atual nao existe na versao do preparo')
        WHERE NOT EXISTS (
          SELECT 1 FROM etapa e
          WHERE e.id_versao = NEW.id_versao
            AND e.ordem = NEW.ordem_etapa_atual
        );
      END;
    ''');

    batch.execute('''
      CREATE TRIGGER trg_preparo_etapa_atual_check_update
      BEFORE UPDATE OF ordem_etapa_atual, id_versao ON preparo
      BEGIN
        SELECT RAISE(ABORT, 'ordem_etapa_atual nao existe na versao do preparo')
        WHERE NOT EXISTS (
          SELECT 1 FROM etapa e
          WHERE e.id_versao = NEW.id_versao
            AND e.ordem = NEW.ordem_etapa_atual
        );
      END;
    ''');

    await batch.commit(noResult: true);
  }

  /// Gancho de migração sem destruição de dados para futuras versões de esquema.
  static Future<void> _aoAtualizar(Database db, int versaoAntiga, int versaoNova) async {
    // Exemplo para futuras versões:
    // if (versaoAntiga < 2) { await db.execute('ALTER TABLE ...'); }
  }

  /// Recupera o usuário local provisório existente ou cria um novo com UUID estável e email nulo.
  Future<Usuario> obterOuCriarUsuarioProvisorio() async {
    if (_db == null || !_db!.isOpen) {
      // Usuário simulado caso estejamos em ambiente sem banco físico (ex: Web)
      return const Usuario(
        idUsuario: 'usuario-web-provisorio',
        nomeExibicao: 'Cozinheiro Local',
        email: null,
        perfil: 'usuario',
      );
    }

    final configs = await _db!.query(
      'configuracao_local',
      where: 'chave = ?',
      whereArgs: ['id_usuario_ativo'],
      limit: 1,
    );

    if (configs.isNotEmpty) {
      final idAtivo = configs.first['valor'] as String;
      final usuarios = await _db!.query(
        'usuario',
        where: 'id_usuario = ?',
        whereArgs: [idAtivo],
        limit: 1,
      );
      if (usuarios.isNotEmpty) {
        return Usuario.fromMap(usuarios.first);
      }
    }

    // Criar novo usuário provisório
    final novoId = const Uuid().v4();
    final novoUsuario = Usuario(
      idUsuario: novoId,
      nomeExibicao: 'Cozinheiro Local',
      email: null,
      perfil: 'usuario',
    );

    await _db!.transaction((txn) async {
      await txn.insert('usuario', novoUsuario.toMap());
      await txn.insert(
        'configuracao_local',
        {'chave': 'id_usuario_ativo', 'valor': novoId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    return novoUsuario;
  }
}
