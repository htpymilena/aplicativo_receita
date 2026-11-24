import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../entidades/entidades.dart';
import 'banco_dados.dart';
import 'repositorio_receitas.dart';

/// Item de conferência com dados do ingrediente para exibição no checklist.
class ConferenciaItem {
  final String idItem;
  final String idIngrediente;
  final String nomeIngrediente;
  final String medida;
  final int ordem;
  final String estado; // 'nao_conferido' | 'tenho' | 'falta'

  const ConferenciaItem({
    required this.idItem,
    required this.idIngrediente,
    required this.nomeIngrediente,
    required this.medida,
    required this.ordem,
    required this.estado,
  });

  ConferenciaItem copyWith({String? estado}) {
    return ConferenciaItem(
      idItem: idItem,
      idIngrediente: idIngrediente,
      nomeIngrediente: nomeIngrediente,
      medida: medida,
      ordem: ordem,
      estado: estado ?? this.estado,
    );
  }
}

/// Preparo detalhado contendo versão, conferências, etapas e avaliação.
class PreparoDetalhado {
  final Preparo preparo;
  final VersaoReceita versao;
  final Receita receita;
  final List<ConferenciaItem> conferencias;
  final List<Etapa> etapas;
  final Avaliacao? avaliacao;

  const PreparoDetalhado({
    required this.preparo,
    required this.versao,
    required this.receita,
    required this.conferencias,
    required this.etapas,
    this.avaliacao,
  });

  int get totalItens => conferencias.length;
  int get totalConferidos => conferencias.where((c) => c.estado != 'nao_conferido').length;
  int get totalTenho => conferencias.where((c) => c.estado == 'tenho').length;
  int get totalFalta => conferencias.where((c) => c.estado == 'falta').length;
  bool get temFaltantes => totalFalta > 0;
  int get totalEtapas => etapas.length;
}

/// Resumo de preparo para listagem no Início e no Histórico.
class PreparoResumo {
  final String idPreparo;
  final String idReceita;
  final String idVersao;
  final String tituloReceita;
  final String? fotoLocal;
  final DateTime iniciadoEm;
  final DateTime? concluidoEm;
  final int ordemEtapaAtual;
  final int totalEtapas;
  final int? estrelas;
  final bool receitaExcluida;

  const PreparoResumo({
    required this.idPreparo,
    required this.idReceita,
    required this.idVersao,
    required this.tituloReceita,
    this.fotoLocal,
    required this.iniciadoEm,
    this.concluidoEm,
    required this.ordemEtapaAtual,
    required this.totalEtapas,
    this.estrelas,
    this.receitaExcluida = false,
  });

  bool get emAndamento => concluidoEm == null;
}

/// Repositório de persistência e consulta de preparos no SQLite (com fallback em memória).
class RepositorioPreparos {
  final BancoDados _bancoDados;
  final bool? forcarMemoria;

  // Armazenamento estático em memória para fallback (Web ou testes sem banco físico)
  static final List<Preparo> _preparosMem = [];
  static final List<Conferencia> _conferenciasMem = [];
  static final List<Avaliacao> _avaliacoesMem = [];

  @visibleForTesting
  static void limparMemoriaWeb() {
    _preparosMem.clear();
    _conferenciasMem.clear();
    _avaliacoesMem.clear();
  }

  RepositorioPreparos({BancoDados? bancoDados, this.forcarMemoria})
      : _bancoDados = bancoDados ?? BancoDados.instancia;

  bool get _usarMemoria =>
      forcarMemoria ?? (kIsWeb || _bancoDados.database == null || !_bancoDados.database!.isOpen);

  Database get _db {
    final db = _bancoDados.database;
    if (db == null || !db.isOpen) {
      throw StateError('O banco de dados não está inicializado ou aberto.');
    }
    return db;
  }

  /// Inicia transacionalmente um novo preparo para a versão atual de uma receita própria do usuário.
  Future<PreparoDetalhado> iniciarPreparo({
    required String idUsuario,
    required String idReceita,
  }) async {
    const uuid = Uuid();
    final idPreparo = uuid.v4();
    final agoraUtc = DateTime.now().toUtc();

    if (_usarMemoria) {
      return _iniciarPreparoMemoria(
        idPreparo: idPreparo,
        idUsuario: idUsuario,
        idReceita: idReceita,
        agoraUtc: agoraUtc,
      );
    }

    return await _db.transaction<PreparoDetalhado>((txn) async {
      // 1. Busca a receita e valida autoria e disponibilidade
      final receitasRows = await txn.query(
        'receita',
        where: 'id_receita = ? AND id_autor = ? AND excluida_em IS NULL',
        whereArgs: [idReceita, idUsuario],
      );
      if (receitasRows.isEmpty) {
        throw StateError('Receita não encontrada, excluída ou não pertence ao usuário.');
      }
      final receita = Receita.fromMap(receitasRows.first);

      // 2. Busca a versão mais recente
      final versoesRows = await txn.query(
        'versao_receita',
        where: 'id_receita = ?',
        whereArgs: [idReceita],
        orderBy: 'numero_versao DESC',
        limit: 1,
      );
      if (versoesRows.isEmpty) {
        throw StateError('A receita não possui nenhuma versão cadastrada.');
      }
      final versao = VersaoReceita.fromMap(versoesRows.first);

      // 3. Busca itens e ingredientes
      final itensRows = await txn.rawQuery('''
        SELECT ir.*, i.nome as nome_ingrediente
        FROM item_receita ir
        JOIN ingrediente i ON ir.id_ingrediente = i.id_ingrediente
        WHERE ir.id_versao = ?
        ORDER BY ir.ordem ASC
      ''', [versao.idVersao]);
      if (itensRows.isEmpty) {
        throw StateError('A versão da receita não possui ingredientes cadastrados.');
      }

      // 4. Busca etapas
      final etapasRows = await txn.query(
        'etapa',
        where: 'id_versao = ?',
        whereArgs: [versao.idVersao],
        orderBy: 'ordem ASC',
      );
      if (etapasRows.isEmpty) {
        throw StateError('A versão da receita não possui etapas cadastradas.');
      }

      // 5. Insere preparo
      final novoPreparo = Preparo(
        idPreparo: idPreparo,
        idUsuario: idUsuario,
        idVersao: versao.idVersao,
        iniciadoEm: agoraUtc,
        ordemEtapaAtual: 1,
      );
      await txn.insert('preparo', novoPreparo.toMap());

      // 6. Insere conferências para cada item da versão
      final conferencias = <ConferenciaItem>[];
      for (final row in itensRows) {
        final idItem = row['id_item'] as String;
        final conf = Conferencia(
          idPreparo: idPreparo,
          idItem: idItem,
          estado: 'nao_conferido',
        );
        await txn.insert('conferencia', conf.toMap());

        conferencias.add(ConferenciaItem(
          idItem: idItem,
          idIngrediente: row['id_ingrediente'] as String,
          nomeIngrediente: row['nome_ingrediente'] as String,
          medida: row['medida'] as String,
          ordem: row['ordem'] as int,
          estado: 'nao_conferido',
        ));
      }

      final etapas = etapasRows.map((e) => Etapa.fromMap(e)).toList();

      return PreparoDetalhado(
        preparo: novoPreparo,
        versao: versao,
        receita: receita,
        conferencias: conferencias,
        etapas: etapas,
      );
    });
  }

  /// Obtém o preparo detalhado com itens, conferências e etapas da versão iniciada.
  Future<PreparoDetalhado?> obterPreparoDetalhado({
    required String idPreparo,
    required String idUsuario,
  }) async {
    if (_usarMemoria) {
      return _obterPreparoDetalhadoMemoria(idPreparo: idPreparo, idUsuario: idUsuario);
    }

    final preparosRows = await _db.rawQuery('''
      SELECT p.*,
             v.id_receita, v.numero_versao, v.titulo, v.categoria, v.foto_local, v.foto_remota,
             r.id_autor, r.origem, r.visibilidade, r.estado_moderacao, r.excluida_em
      FROM preparo p
      JOIN versao_receita v ON p.id_versao = v.id_versao
      JOIN receita r ON v.id_receita = r.id_receita
      WHERE p.id_preparo = ? AND p.id_usuario = ?
    ''', [idPreparo, idUsuario]);

    if (preparosRows.isEmpty) {
      return null;
    }

    final row = preparosRows.first;
    final preparo = Preparo.fromMap(row);
    final versao = VersaoReceita(
      idVersao: preparo.idVersao,
      idReceita: row['id_receita'] as String,
      numeroVersao: row['numero_versao'] as int,
      titulo: row['titulo'] as String,
      categoria: row['categoria'] as String,
      fotoLocal: row['foto_local'] as String?,
      fotoRemota: row['foto_remota'] as String?,
    );
    final receita = Receita(
      idReceita: row['id_receita'] as String,
      idAutor: row['id_autor'] as String?,
      origem: row['origem'] as String,
      visibilidade: row['visibilidade'] as String,
      estadoModeracao: row['estado_moderacao'] as String,
      excluidaEm: row['excluida_em'] != null ? DateTime.parse(row['excluida_em'] as String).toUtc() : null,
    );

    // Conferências com dados dos ingredientes
    final conferenciasRows = await _db.rawQuery('''
      SELECT c.id_item, c.estado, ir.id_ingrediente, ir.ordem, ir.medida, i.nome as nome_ingrediente
      FROM conferencia c
      JOIN item_receita ir ON c.id_item = ir.id_item
      JOIN ingrediente i ON ir.id_ingrediente = i.id_ingrediente
      WHERE c.id_preparo = ?
      ORDER BY ir.ordem ASC
    ''', [idPreparo]);

    final conferencias = conferenciasRows.map((c) {
      return ConferenciaItem(
        idItem: c['id_item'] as String,
        idIngrediente: c['id_ingrediente'] as String,
        nomeIngrediente: c['nome_ingrediente'] as String,
        medida: c['medida'] as String,
        ordem: c['ordem'] as int,
        estado: c['estado'] as String,
      );
    }).toList();

    // Etapas da versão
    final etapasRows = await _db.query(
      'etapa',
      where: 'id_versao = ?',
      whereArgs: [preparo.idVersao],
      orderBy: 'ordem ASC',
    );
    final etapas = etapasRows.map((e) => Etapa.fromMap(e)).toList();

    // Avaliação opcional
    final avaliacoesRows = await _db.query(
      'avaliacao',
      where: 'id_preparo = ?',
      whereArgs: [idPreparo],
    );
    final avaliacao = avaliacoesRows.isNotEmpty ? Avaliacao.fromMap(avaliacoesRows.first) : null;

    return PreparoDetalhado(
      preparo: preparo,
      versao: versao,
      receita: receita,
      conferencias: conferencias,
      etapas: etapas,
      avaliacao: avaliacao,
    );
  }

  /// Altera o estado de uma conferência de ingrediente com validação de propriedade e andamento.
  Future<void> atualizarConferencia({
    required String idPreparo,
    required String idItem,
    required String novoEstado,
    required String idUsuario,
  }) async {
    const estadosValidos = {'nao_conferido', 'tenho', 'falta'};
    if (!estadosValidos.contains(novoEstado)) {
      throw ArgumentError('Estado inválido para conferência: $novoEstado');
    }

    if (_usarMemoria) {
      return _atualizarConferenciaMemoria(
        idPreparo: idPreparo,
        idItem: idItem,
        novoEstado: novoEstado,
        idUsuario: idUsuario,
      );
    }

    // Valida que o preparo pertence ao usuário e está em andamento
    final preparos = await _db.query(
      'preparo',
      where: 'id_preparo = ? AND id_usuario = ?',
      whereArgs: [idPreparo, idUsuario],
    );
    if (preparos.isEmpty) {
      throw StateError('Preparo não encontrado ou não pertence ao usuário.');
    }
    if (preparos.first['concluido_em'] != null) {
      throw StateError('Não é possível alterar conferências de um preparo já concluído.');
    }

    final idVersao = preparos.first['id_versao'] as String;

    // Valida que o item pertence à versão do preparo
    final itens = await _db.query(
      'item_receita',
      where: 'id_item = ? AND id_versao = ?',
      whereArgs: [idItem, idVersao],
    );
    if (itens.isEmpty) {
      throw StateError('O item não pertence à versão associada a este preparo.');
    }

    final rowsAfetadas = await _db.update(
      'conferencia',
      {'estado': novoEstado},
      where: 'id_preparo = ? AND id_item = ?',
      whereArgs: [idPreparo, idItem],
    );
    if (rowsAfetadas == 0) {
      throw StateError('Conferência não encontrada para o preparo e item informados.');
    }
  }

  /// Atualiza a etapa atual do preparo em andamento para retomada futura.
  Future<void> atualizarEtapaAtual({
    required String idPreparo,
    required int novaOrdem,
    required String idUsuario,
  }) async {
    if (novaOrdem < 1) {
      throw ArgumentError('A ordem da etapa deve ser maior ou igual a 1.');
    }

    if (_usarMemoria) {
      return _atualizarEtapaAtualMemoria(
        idPreparo: idPreparo,
        novaOrdem: novaOrdem,
        idUsuario: idUsuario,
      );
    }

    final preparos = await _db.query(
      'preparo',
      where: 'id_preparo = ? AND id_usuario = ?',
      whereArgs: [idPreparo, idUsuario],
    );
    if (preparos.isEmpty) {
      throw StateError('Preparo não encontrado ou não pertence ao usuário.');
    }
    if (preparos.first['concluido_em'] != null) {
      throw StateError('Não é possível alterar a etapa de um preparo já concluído.');
    }

    final idVersao = preparos.first['id_versao'] as String;
    final etapasCountResult = await _db.rawQuery(
      'SELECT COUNT(*) as total FROM etapa WHERE id_versao = ?',
      [idVersao],
    );
    final totalEtapas = Sqflite.firstIntValue(etapasCountResult) ?? 0;
    if (novaOrdem > totalEtapas) {
      throw ArgumentError('Ordem da etapa ($novaOrdem) excede o total de etapas ($totalEtapas).');
    }

    await _db.update(
      'preparo',
      {'ordem_etapa_atual': novaOrdem},
      where: 'id_preparo = ?',
      whereArgs: [idPreparo],
    );
  }

  /// Conclui o preparo registrando a data e hora em UTC. É idempotente.
  Future<DateTime> concluirPreparo({
    required String idPreparo,
    required String idUsuario,
  }) async {
    if (_usarMemoria) {
      return _concluirPreparoMemoria(idPreparo: idPreparo, idUsuario: idUsuario);
    }

    final preparos = await _db.query(
      'preparo',
      where: 'id_preparo = ? AND id_usuario = ?',
      whereArgs: [idPreparo, idUsuario],
    );
    if (preparos.isEmpty) {
      throw StateError('Preparo não encontrado ou não pertence ao usuário.');
    }

    final concluidoJa = preparos.first['concluido_em'] as String?;
    if (concluidoJa != null) {
      return DateTime.parse(concluidoJa).toUtc();
    }

    final agoraUtc = DateTime.now().toUtc();
    await _db.update(
      'preparo',
      {'concluido_em': agoraUtc.toIso8601String()},
      where: 'id_preparo = ?',
      whereArgs: [idPreparo],
    );

    return agoraUtc;
  }

  /// Consulta preparos em andamento por usuário, ordenados por data de início decrescente.
  Future<List<PreparoResumo>> listarPreparosEmAndamento({
    required String idUsuario,
  }) async {
    if (_usarMemoria) {
      return _listarPreparosEmAndamentoMemoria(idUsuario: idUsuario);
    }

    final rows = await _db.rawQuery('''
      SELECT p.id_preparo, p.id_usuario, p.id_versao, p.iniciado_em, p.concluido_em, p.ordem_etapa_atual,
             v.id_receita, v.titulo as titulo_receita, v.foto_local,
             r.excluida_em,
             (SELECT COUNT(*) FROM etapa e WHERE e.id_versao = p.id_versao) as total_etapas,
             a.estrelas
      FROM preparo p
      JOIN versao_receita v ON p.id_versao = v.id_versao
      JOIN receita r ON v.id_receita = r.id_receita
      LEFT JOIN avaliacao a ON p.id_preparo = a.id_preparo
      WHERE p.id_usuario = ? AND p.concluido_em IS NULL
      ORDER BY p.iniciado_em DESC, p.id_preparo DESC
    ''', [idUsuario]);

    return rows.map((r) {
      return PreparoResumo(
        idPreparo: r['id_preparo'] as String,
        idReceita: r['id_receita'] as String,
        idVersao: r['id_versao'] as String,
        tituloReceita: r['titulo_receita'] as String,
        fotoLocal: r['foto_local'] as String?,
        iniciadoEm: DateTime.parse(r['iniciado_em'] as String).toUtc(),
        concluidoEm: null,
        ordemEtapaAtual: (r['ordem_etapa_atual'] as int?) ?? 1,
        totalEtapas: (r['total_etapas'] as int?) ?? 0,
        estrelas: r['estrelas'] as int?,
        receitaExcluida: r['excluida_em'] != null,
      );
    }).toList();
  }

  /// Consulta preparos concluídos por usuário, ordenados por data de conclusão decrescente.
  Future<List<PreparoResumo>> listarPreparosConcluidos({
    required String idUsuario,
  }) async {
    if (_usarMemoria) {
      return _listarPreparosConcluidosMemoria(idUsuario: idUsuario);
    }

    final rows = await _db.rawQuery('''
      SELECT p.id_preparo, p.id_usuario, p.id_versao, p.iniciado_em, p.concluido_em, p.ordem_etapa_atual,
             v.id_receita, v.titulo as titulo_receita, v.foto_local,
             r.excluida_em,
             (SELECT COUNT(*) FROM etapa e WHERE e.id_versao = p.id_versao) as total_etapas,
             a.estrelas
      FROM preparo p
      JOIN versao_receita v ON p.id_versao = v.id_versao
      JOIN receita r ON v.id_receita = r.id_receita
      LEFT JOIN avaliacao a ON p.id_preparo = a.id_preparo
      WHERE p.id_usuario = ? AND p.concluido_em IS NOT NULL
      ORDER BY p.concluido_em DESC, p.id_preparo DESC
    ''', [idUsuario]);

    return rows.map((r) {
      return PreparoResumo(
        idPreparo: r['id_preparo'] as String,
        idReceita: r['id_receita'] as String,
        idVersao: r['id_versao'] as String,
        tituloReceita: r['titulo_receita'] as String,
        fotoLocal: r['foto_local'] as String?,
        iniciadoEm: DateTime.parse(r['iniciado_em'] as String).toUtc(),
        concluidoEm: DateTime.parse(r['concluido_em'] as String).toUtc(),
        ordemEtapaAtual: (r['ordem_etapa_atual'] as int?) ?? 1,
        totalEtapas: (r['total_etapas'] as int?) ?? 0,
        estrelas: r['estrelas'] as int?,
        receitaExcluida: r['excluida_em'] != null,
      );
    }).toList();
  }

  /// Salva ou atualiza a avaliação de um preparo concluído do usuário ativo (1 a 5 estrelas, sempre privada).
  Future<Avaliacao> salvarAvaliacao({
    required String idPreparo,
    required String idUsuario,
    required int estrelas,
  }) async {
    if (estrelas < 1 || estrelas > 5) {
      throw ArgumentError('A avaliação deve ser entre 1 e 5 estrelas.');
    }

    if (_usarMemoria) {
      return _salvarAvaliacaoMemoria(
        idPreparo: idPreparo,
        idUsuario: idUsuario,
        estrelas: estrelas,
      );
    }

    final preparos = await _db.query(
      'preparo',
      where: 'id_preparo = ? AND id_usuario = ?',
      whereArgs: [idPreparo, idUsuario],
    );
    if (preparos.isEmpty) {
      throw StateError('Preparo não encontrado ou não pertence ao usuário.');
    }
    if (preparos.first['concluido_em'] == null) {
      throw StateError('Não é possível avaliar um preparo que ainda não foi concluído.');
    }

    final agoraUtc = DateTime.now().toUtc();
    final avaliacao = Avaliacao(
      idPreparo: idPreparo,
      estrelas: estrelas,
      visibilidade: 'privada',
      estadoModeracao: 'liberada',
      avaliadaEm: agoraUtc,
    );

    final existentes = await _db.query(
      'avaliacao',
      where: 'id_preparo = ?',
      whereArgs: [idPreparo],
    );

    if (existentes.isEmpty) {
      await _db.insert('avaliacao', avaliacao.toMap());
    } else {
      await _db.update(
        'avaliacao',
        avaliacao.toMap(),
        where: 'id_preparo = ?',
        whereArgs: [idPreparo],
      );
    }

    return avaliacao;
  }

  // ==========================================
  // Implementação em memória (Fallback Web/Testes)
  // ==========================================

  PreparoDetalhado _iniciarPreparoMemoria({
    required String idPreparo,
    required String idUsuario,
    required String idReceita,
    required DateTime agoraUtc,
  }) {
    final rec = RepositorioReceitas.receitasWeb.where(
      (r) => r.receita.idReceita == idReceita && r.receita.excluidaEm == null,
    ).firstOrNull;

    final versao = rec?.versao ?? VersaoReceita(
      idVersao: 'versao_mem_$idReceita',
      idReceita: idReceita,
      numeroVersao: 1,
      titulo: 'Receita Web',
      categoria: 'Sem categoria',
    );

    final receita = rec?.receita ?? Receita(
      idReceita: idReceita,
      idAutor: idUsuario,
      origem: 'usuario',
      visibilidade: 'privada',
      estadoModeracao: 'liberada',
    );

    final novoPreparo = Preparo(
      idPreparo: idPreparo,
      idUsuario: idUsuario,
      idVersao: versao.idVersao,
      iniciadoEm: agoraUtc,
      ordemEtapaAtual: 1,
    );
    _preparosMem.add(novoPreparo);

    final confs = <ConferenciaItem>[];
    if (rec != null && rec.itens.isNotEmpty) {
      for (final item in rec.itens) {
        _conferenciasMem.add(Conferencia(
          idPreparo: idPreparo,
          idItem: item.idItem,
          estado: 'nao_conferido',
        ));
        confs.add(ConferenciaItem(
          idItem: item.idItem,
          idIngrediente: item.idIngrediente,
          nomeIngrediente: item.nomeIngrediente,
          medida: item.medida,
          ordem: item.ordem,
          estado: 'nao_conferido',
        ));
      }
    } else {
      _conferenciasMem.add(Conferencia(
        idPreparo: idPreparo,
        idItem: 'item_padrao',
        estado: 'nao_conferido',
      ));
      confs.add(const ConferenciaItem(
        idItem: 'item_padrao',
        idIngrediente: 'ing_padrao',
        nomeIngrediente: 'Ingrediente Base',
        medida: '1 porção',
        ordem: 1,
        estado: 'nao_conferido',
      ));
    }

    final etapas = (rec != null && rec.etapas.isNotEmpty)
        ? rec.etapas
        : [Etapa(idEtapa: 'e1', idVersao: versao.idVersao, ordem: 1, instrucao: 'Prepare os ingredientes.')];

    return PreparoDetalhado(
      preparo: novoPreparo,
      versao: versao,
      receita: receita,
      conferencias: confs,
      etapas: etapas,
    );
  }

  PreparoDetalhado? _obterPreparoDetalhadoMemoria({
    required String idPreparo,
    required String idUsuario,
  }) {
    final preparo = _preparosMem.where((p) => p.idPreparo == idPreparo).firstOrNull;
    if (preparo == null) return null;

    final rec = RepositorioReceitas.receitasWeb.where(
      (r) => r.versao.idVersao == preparo.idVersao,
    ).firstOrNull;

    final titulo = rec?.versao.titulo ?? 'Receita em Memória';
    final versao = rec?.versao ?? VersaoReceita(
      idVersao: preparo.idVersao,
      idReceita: 'rec_${preparo.idVersao}',
      numeroVersao: 1,
      titulo: titulo,
      categoria: 'Sem categoria',
    );

    final receita = rec?.receita ?? Receita(
      idReceita: versao.idReceita,
      idAutor: idUsuario,
      origem: 'usuario',
      visibilidade: 'privada',
      estadoModeracao: 'liberada',
    );

    final confs = _conferenciasMem
        .where((c) => c.idPreparo == idPreparo)
        .map((c) {
          final itemOriginal = rec?.itens.where((i) => i.idItem == c.idItem).firstOrNull;
          return ConferenciaItem(
            idItem: c.idItem,
            idIngrediente: itemOriginal?.idIngrediente ?? 'ing_${c.idItem}',
            nomeIngrediente: itemOriginal?.nomeIngrediente ?? 'Ingrediente ${c.idItem}',
            medida: itemOriginal?.medida ?? '1 un',
            ordem: itemOriginal?.ordem ?? 1,
            estado: c.estado,
          );
        })
        .toList();

    final etapas = (rec != null && rec.etapas.isNotEmpty)
        ? rec.etapas
        : const [Etapa(idEtapa: 'e1', idVersao: 'v1', ordem: 1, instrucao: 'Instrução 1')];

    final avaliacao = _avaliacoesMem.where((a) => a.idPreparo == idPreparo).firstOrNull;

    return PreparoDetalhado(
      preparo: preparo,
      versao: versao,
      receita: receita,
      conferencias: confs,
      etapas: etapas,
      avaliacao: avaliacao,
    );
  }

  void _atualizarConferenciaMemoria({
    required String idPreparo,
    required String idItem,
    required String novoEstado,
    required String idUsuario,
  }) {
    final idx = _conferenciasMem.indexWhere((c) => c.idPreparo == idPreparo && c.idItem == idItem);
    if (idx != -1) {
      _conferenciasMem[idx] = Conferencia(idPreparo: idPreparo, idItem: idItem, estado: novoEstado);
    } else {
      _conferenciasMem.add(Conferencia(idPreparo: idPreparo, idItem: idItem, estado: novoEstado));
    }
  }

  void _atualizarEtapaAtualMemoria({
    required String idPreparo,
    required int novaOrdem,
    required String idUsuario,
  }) {
    final idx = _preparosMem.indexWhere((p) => p.idPreparo == idPreparo && p.idUsuario == idUsuario);
    if (idx != -1) {
      final p = _preparosMem[idx];
      _preparosMem[idx] = Preparo(
        idPreparo: p.idPreparo,
        idUsuario: p.idUsuario,
        idVersao: p.idVersao,
        iniciadoEm: p.iniciadoEm,
        concluidoEm: p.concluidoEm,
        ordemEtapaAtual: novaOrdem,
      );
    }
  }

  DateTime _concluirPreparoMemoria({
    required String idPreparo,
    required String idUsuario,
  }) {
    final idx = _preparosMem.indexWhere((p) => p.idPreparo == idPreparo);
    final agora = DateTime.now().toUtc();
    if (idx != -1) {
      final p = _preparosMem[idx];
      if (p.concluidoEm != null) return p.concluidoEm!;
      _preparosMem[idx] = Preparo(
        idPreparo: p.idPreparo,
        idUsuario: p.idUsuario,
        idVersao: p.idVersao,
        iniciadoEm: p.iniciadoEm,
        concluidoEm: agora,
        ordemEtapaAtual: p.ordemEtapaAtual,
      );
    } else {
      _preparosMem.add(Preparo(
        idPreparo: idPreparo,
        idUsuario: idUsuario,
        idVersao: 'versao_mem',
        iniciadoEm: agora,
        concluidoEm: agora,
      ));
    }
    return agora;
  }

  List<PreparoResumo> _listarPreparosEmAndamentoMemoria({required String idUsuario}) {
    return _preparosMem
        .where((p) => p.idUsuario == idUsuario && p.emAndamento)
        .map((p) {
          final rec = RepositorioReceitas.receitasWeb.where(
            (r) => r.versao.idVersao == p.idVersao,
          ).firstOrNull;
          return PreparoResumo(
            idPreparo: p.idPreparo,
            idReceita: rec?.receita.idReceita ?? 'rec_${p.idVersao}',
            idVersao: p.idVersao,
            tituloReceita: rec?.versao.titulo ?? 'Receita em Memória',
            fotoLocal: rec?.versao.fotoLocal,
            iniciadoEm: p.iniciadoEm,
            concluidoEm: null,
            ordemEtapaAtual: p.ordemEtapaAtual,
            totalEtapas: rec?.etapas.length ?? 1,
            receitaExcluida: rec?.receita.excluidaEm != null,
          );
        })
        .toList();
  }

  List<PreparoResumo> _listarPreparosConcluidosMemoria({required String idUsuario}) {
    return _preparosMem
        .where((p) => p.idUsuario == idUsuario && !p.emAndamento)
        .map((p) {
          final rec = RepositorioReceitas.receitasWeb.where(
            (r) => r.versao.idVersao == p.idVersao,
          ).firstOrNull;
          final avaliacao = _avaliacoesMem.where((a) => a.idPreparo == p.idPreparo).firstOrNull;
          return PreparoResumo(
            idPreparo: p.idPreparo,
            idReceita: rec?.receita.idReceita ?? 'rec_${p.idVersao}',
            idVersao: p.idVersao,
            tituloReceita: rec?.versao.titulo ?? 'Receita em Memória',
            fotoLocal: rec?.versao.fotoLocal,
            iniciadoEm: p.iniciadoEm,
            concluidoEm: p.concluidoEm,
            ordemEtapaAtual: p.ordemEtapaAtual,
            totalEtapas: rec?.etapas.length ?? 1,
            estrelas: avaliacao?.estrelas,
            receitaExcluida: rec?.receita.excluidaEm != null,
          );
        })
        .toList();
  }

  Avaliacao _salvarAvaliacaoMemoria({
    required String idPreparo,
    required String idUsuario,
    required int estrelas,
  }) {
    final agora = DateTime.now().toUtc();
    final avaliacao = Avaliacao(
      idPreparo: idPreparo,
      estrelas: estrelas,
      visibilidade: 'privada',
      estadoModeracao: 'liberada',
      avaliadaEm: agora,
    );
    final idx = _avaliacoesMem.indexWhere((a) => a.idPreparo == idPreparo);
    if (idx != -1) {
      _avaliacoesMem[idx] = avaliacao;
    } else {
      _avaliacoesMem.add(avaliacao);
    }
    return avaliacao;
  }
}
