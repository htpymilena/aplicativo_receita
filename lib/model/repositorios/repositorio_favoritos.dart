import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../entidades/favorito.dart';
import 'banco_dados.dart';
import 'repositorio_receitas.dart';

/// Repositório de persistência e consulta de receitas favoritas (SQLite e fallback Web em memória).
class RepositorioFavoritos {
  final BancoDados _bancoDados;
  final bool? forcarMemoria;

  RepositorioFavoritos({BancoDados? bancoDados, this.forcarMemoria})
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

  // Armazenamento em memória para ambiente Web ou execução sem SQLite físico
  static final List<Favorito> _favoritosWeb = [];

  @visibleForTesting
  static void limparMemoria() {
    _favoritosWeb.clear();
  }

  /// Remove favoritos de uma receita em memória (usado na exclusão lógica).
  static void removerFavoritoEmMemoria(String idReceita) {
    _favoritosWeb.removeWhere((f) => f.idReceita == idReceita);
  }

  /// Consulta se a receita está favoritada pelo usuário ativo.
  Future<bool> ehFavorito({
    required String idUsuario,
    required String idReceita,
  }) async {
    if (_usarMemoria) {
      return _favoritosWeb.any(
        (f) => f.idUsuario == idUsuario && f.idReceita == idReceita,
      );
    }

    final resultados = await _db.query(
      'favorito',
      columns: ['id_receita'],
      where: 'id_usuario = ? AND id_receita = ?',
      whereArgs: [idUsuario, idReceita],
      limit: 1,
    );
    return resultados.isNotEmpty;
  }

  /// Adiciona uma receita própria ou externa copiada aos favoritos de forma idempotente.
  /// Valida que a receita existe, não está excluída e pertence ou está associada ao usuário.
  Future<void> adicionarFavorito({
    required String idUsuario,
    required String idReceita,
    DateTime? salvoEm,
  }) async {
    final dataSalvo = (salvoEm ?? DateTime.now().toUtc()).toUtc();

    if (_usarMemoria) {
      // Valida acesso à receita própria ou receita externa associada ao usuário em memória
      final existe = RepositorioReceitas.receitasWeb.any(
        (r) =>
            r.receita.idReceita == idReceita &&
            r.receita.excluidaEm == null &&
            ((r.receita.origem == 'usuario' && r.receita.idAutor == idUsuario) ||
                (r.receita.origem == 'themealdb' &&
                    RepositorioReceitas.receitaExternaAssociadaAoUsuario(
                        idUsuario, idReceita))),
      );
      if (!existe) {
        throw StateError(
          'Receita não encontrada, excluída ou não pertence ao usuário.',
        );
      }

      // Adição idempotente
      final jaExiste = _favoritosWeb.any(
        (f) => f.idUsuario == idUsuario && f.idReceita == idReceita,
      );
      if (!jaExiste) {
        _favoritosWeb.add(
          Favorito(
            idUsuario: idUsuario,
            idReceita: idReceita,
            salvoEm: dataSalvo,
          ),
        );
      }
      return;
    }

    // Valida acesso à receita própria ou externa no SQLite
    final validacao = await _db.rawQuery('''
      SELECT r.id_receita
      FROM receita r
      LEFT JOIN receita_externa_usuario reu 
        ON r.id_receita = reu.id_receita AND reu.id_usuario = ?
      WHERE r.id_receita = ?
        AND r.excluida_em IS NULL
        AND (
          (r.origem = 'usuario' AND r.id_autor = ?)
          OR (r.origem = 'themealdb' AND reu.id_usuario IS NOT NULL)
        )
      LIMIT 1
    ''', [idUsuario, idReceita, idUsuario]);

    if (validacao.isEmpty) {
      throw StateError(
        'Receita não encontrada, excluída ou não pertence ao usuário.',
      );
    }

    // Adição idempotente usando ConflictAlgorithm.ignore
    await _db.insert(
      'favorito',
      {
        'id_usuario': idUsuario,
        'id_receita': idReceita,
        'salvo_em': dataSalvo.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Remove o vínculo de favorito do usuário para a receita.
  Future<void> removerFavorito({
    required String idUsuario,
    required String idReceita,
  }) async {
    if (_usarMemoria) {
      _favoritosWeb.removeWhere(
        (f) => f.idUsuario == idUsuario && f.idReceita == idReceita,
      );
      return;
    }

    await _db.delete(
      'favorito',
      where: 'id_usuario = ? AND id_receita = ?',
      whereArgs: [idUsuario, idReceita],
    );
  }

  /// Lista os favoritos do usuário com a versão mais recente da receita (própria ou externa).
  /// Ordenado por `salvo_em DESC`, com desempate por `id_receita ASC`.
  Future<List<ReceitaResumo>> listarFavoritos(String idUsuario) async {
    if (_usarMemoria) {
      final favsUsuario = _favoritosWeb
          .where((f) => f.idUsuario == idUsuario)
          .toList();

      final lista = <ReceitaResumo>[];
      for (final f in favsUsuario) {
        final recMatches = RepositorioReceitas.receitasWeb.where(
          (r) =>
              r.receita.idReceita == f.idReceita &&
              r.receita.excluidaEm == null &&
              ((r.receita.origem == 'usuario' && r.receita.idAutor == idUsuario) ||
                  (r.receita.origem == 'themealdb' &&
                      RepositorioReceitas.receitaExternaAssociadaAoUsuario(
                          idUsuario, f.idReceita))),
        );
        if (recMatches.isNotEmpty) {
          final r = recMatches.first;
          lista.add(
            ReceitaResumo(
              idReceita: r.receita.idReceita,
              titulo: r.versao.titulo,
              categoria: r.versao.categoria,
              fotoLocal: r.versao.fotoLocal,
              fotoRemota: r.versao.fotoRemota,
              numeroVersao: r.versao.numeroVersao,
              excluidaEm: r.receita.excluidaEm,
              salvoEm: f.salvoEm,
              origem: r.receita.origem,
              idThemealdb: r.receita.idThemealdb,
            ),
          );
        }
      }

      lista.sort((a, b) {
        final comp = (b.salvoEm ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.salvoEm ?? DateTime.fromMillisecondsSinceEpoch(0));
        if (comp != 0) return comp;
        return a.idReceita.compareTo(b.idReceita);
      });

      return lista;
    }

    final resultados = await _db.rawQuery('''
      SELECT 
        f.id_receita,
        f.salvo_em,
        r.origem,
        r.id_themealdb,
        r.excluida_em,
        v.titulo,
        v.categoria,
        v.foto_local,
        v.foto_remota,
        v.numero_versao
      FROM favorito f
      JOIN receita r ON f.id_receita = r.id_receita
      LEFT JOIN receita_externa_usuario reu 
        ON r.id_receita = reu.id_receita AND reu.id_usuario = f.id_usuario
      JOIN versao_receita v ON r.id_receita = v.id_receita
      WHERE f.id_usuario = ?
        AND r.excluida_em IS NULL
        AND (
          (r.origem = 'usuario' AND r.id_autor = f.id_usuario)
          OR (r.origem = 'themealdb' AND reu.id_usuario IS NOT NULL)
        )
        AND v.numero_versao = (
          SELECT MAX(v2.numero_versao)
          FROM versao_receita v2
          WHERE v2.id_receita = r.id_receita
        )
      ORDER BY f.salvo_em DESC, f.id_receita ASC;
    ''', [idUsuario]);

    return resultados.map((row) {
      return ReceitaResumo(
        idReceita: row['id_receita'] as String,
        titulo: row['titulo'] as String,
        categoria: row['categoria'] as String,
        fotoLocal: row['foto_local'] as String?,
        fotoRemota: row['foto_remota'] as String?,
        numeroVersao: row['numero_versao'] as int,
        excluidaEm: row['excluida_em'] != null
            ? DateTime.parse(row['excluida_em'] as String).toUtc()
            : null,
        salvoEm: row['salvo_em'] != null
            ? DateTime.parse(row['salvo_em'] as String).toUtc()
            : null,
        origem: (row['origem'] as String?) ?? 'usuario',
        idThemealdb: row['id_themealdb'] as String?,
      );
    }).toList();
  }
}
