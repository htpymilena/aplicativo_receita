import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../entidades/entidades.dart';
import '../servicos/normalizador_ingredientes.dart';
import '../servicos/quebrador_instrucoes.dart';
import '../servicos/rascunho_receita.dart';
import '../servicos/tradutor_themealdb.dart';
import 'banco_dados.dart';
import 'repositorio_favoritos.dart';

/// Resumo de receita para exibição em listas.
class ReceitaResumo {
  final String idReceita;
  final String titulo;
  final String categoria;
  final String? fotoLocal;
  final String? fotoRemota;
  final int numeroVersao;
  final DateTime? excluidaEm;
  final DateTime? salvoEm;
  final String origem;
  final String? idThemealdb;

  const ReceitaResumo({
    required this.idReceita,
    required this.titulo,
    required this.categoria,
    this.fotoLocal,
    this.fotoRemota,
    required this.numeroVersao,
    this.excluidaEm,
    this.salvoEm,
    this.origem = 'usuario',
    this.idThemealdb,
  });

  /// Caminho local ou URL remota da foto para exibição.
  String? get foto => fotoLocal ?? fotoRemota;
}

/// Item de receita detalhado com nome de exibição do ingrediente.
class ItemReceitaDetalhado {
  final String idItem;
  final String idIngrediente;
  final String nomeIngrediente;
  final int ordem;
  final String medida;

  const ItemReceitaDetalhado({
    required this.idItem,
    required this.idIngrediente,
    required this.nomeIngrediente,
    required this.ordem,
    required this.medida,
  });
}

/// Receita completa incluindo versão ativa, itens e etapas.
class ReceitaCompleta {
  final Receita receita;
  final VersaoReceita versao;
  final List<ItemReceitaDetalhado> itens;
  final List<Etapa> etapas;

  const ReceitaCompleta({
    required this.receita,
    required this.versao,
    required this.itens,
    required this.etapas,
  });
}

/// Repositório de persistência e consulta de receitas próprias no SQLite (com fallback em memória para Web).
class RepositorioReceitas {
  final BancoDados _bancoDados;
  final bool? forcarMemoria;

  // Armazenamento em memória para ambiente Web ou execução sem banco SQLite físico
  static final List<ReceitaCompleta> _receitasWeb = [];
  static final List<Map<String, dynamic>> _receitasExternasUsuarioWeb = [];

  @visibleForTesting
  static void limparMemoriaReceitasExternas() {
    _receitasExternasUsuarioWeb.clear();
  }

  static bool receitaExternaAssociadaAoUsuario(String idUsuario, String idReceita) {
    return _receitasExternasUsuarioWeb.any(
      (m) => m['id_usuario'] == idUsuario && m['id_receita'] == idReceita,
    );
  }

  static List<ReceitaCompleta> get receitasWeb {
    if (kIsWeb && _receitasWeb.isEmpty) {
      _inicializarReceitaExemploWeb();
    }
    return _receitasWeb;
  }

  static void _inicializarReceitaExemploWeb() {
    _receitasWeb.add(
      const ReceitaCompleta(
        receita: Receita(
          idReceita: 'rec_panqueca_banana',
          idAutor: 'usuario-web-provisorio',
          origem: 'usuario',
          visibilidade: 'privada',
          estadoModeracao: 'liberada',
        ),
        versao: VersaoReceita(
          idVersao: 'versao_panqueca_v1',
          idReceita: 'rec_panqueca_banana',
          numeroVersao: 1,
          titulo: 'Panqueca de Banana',
          categoria: 'Café da manhã',
        ),
        itens: [
          ItemReceitaDetalhado(
            idItem: 'item_banana_1',
            idIngrediente: 'ing_banana',
            nomeIngrediente: 'Banana nanica',
            ordem: 1,
            medida: '2 unidades',
          ),
          ItemReceitaDetalhado(
            idItem: 'item_ovo_1',
            idIngrediente: 'ing_ovo',
            nomeIngrediente: 'Ovo',
            ordem: 2,
            medida: '1 unidade',
          ),
          ItemReceitaDetalhado(
            idItem: 'item_aveia_1',
            idIngrediente: 'ing_aveia',
            nomeIngrediente: 'Flocos de aveia',
            ordem: 3,
            medida: '2 colheres de sopa',
          ),
        ],
        etapas: [
          Etapa(
            idEtapa: 'etapa_panqueca_1',
            idVersao: 'versao_panqueca_v1',
            ordem: 1,
            instrucao: 'Amasse as duas bananas maduras em um prato com um garfo até formar um purê.',
          ),
          Etapa(
            idEtapa: 'etapa_panqueca_2',
            idVersao: 'versao_panqueca_v1',
            ordem: 2,
            instrucao: 'Misture o ovo batido e a aveia. Despeje em uma frigideira untada em fogo baixo e doure os dois lados.',
          ),
        ],
      ),
    );
  }

  @visibleForTesting
  static void limparMemoriaWeb() => _receitasWeb.clear();

  RepositorioReceitas({BancoDados? bancoDados, this.forcarMemoria})
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

  /// Cria transacionalmente uma nova receita própria privada, versão 1, itens e etapas.
  Future<ReceitaCompleta> criarReceitaPropria({
    required String idAutor,
    required RascunhoReceita rascunho,
    String? caminhoFotoRelativo,
  }) async {
    const uuid = Uuid();
    final idReceita = uuid.v4();
    final idVersao = uuid.v4();
    final tituloLimpo = rascunho.titulo.trim();
    final categoriaLimpa = (rascunho.categoria != null && rascunho.categoria!.trim().isNotEmpty)
        ? rascunho.categoria!.trim()
        : 'Sem categoria';

    if (_usarMemoria) {
      final receita = Receita(
        idReceita: idReceita,
        idAutor: idAutor,
        origem: 'usuario',
        idThemealdb: null,
        visibilidade: 'privada',
        estadoModeracao: 'liberada',
      );
      final versao = VersaoReceita(
        idVersao: idVersao,
        idReceita: idReceita,
        numeroVersao: 1,
        titulo: tituloLimpo,
        categoria: categoriaLimpa,
        fotoLocal: caminhoFotoRelativo,
      );
      final itens = <ItemReceitaDetalhado>[];
      for (int i = 0; i < rascunho.itens.length; i++) {
        final it = rascunho.itens[i];
        itens.add(ItemReceitaDetalhado(
          idItem: uuid.v4(),
          idIngrediente: uuid.v4(),
          nomeIngrediente: it.nomeIngrediente.trim(),
          ordem: i + 1,
          medida: it.medida.trim(),
        ));
      }
      final etapas = <Etapa>[];
      for (int i = 0; i < rascunho.etapas.length; i++) {
        etapas.add(Etapa(
          idEtapa: uuid.v4(),
          idVersao: idVersao,
          ordem: i + 1,
          instrucao: rascunho.etapas[i].trim(),
        ));
      }
      final completa = ReceitaCompleta(
        receita: receita,
        versao: versao,
        itens: itens,
        etapas: etapas,
      );
      _receitasWeb.add(completa);
      return completa;
    }

    return await _db.transaction((txn) async {
      // 1. Inserir Receita
      final receita = Receita(
        idReceita: idReceita,
        idAutor: idAutor,
        origem: 'usuario',
        idThemealdb: null,
        visibilidade: 'privada',
        estadoModeracao: 'liberada',
      );
      await txn.insert('receita', receita.toMap());

      // 2. Inserir Versão 1
      final versao = VersaoReceita(
        idVersao: idVersao,
        idReceita: idReceita,
        numeroVersao: 1,
        titulo: tituloLimpo,
        categoria: categoriaLimpa,
        fotoLocal: caminhoFotoRelativo,
      );
      await txn.insert('versao_receita', versao.toMap());

      // 3. Inserir Itens e Ingredientes
      final itensDetalhados = <ItemReceitaDetalhado>[];
      for (int i = 0; i < rascunho.itens.length; i++) {
        final itemRascunho = rascunho.itens[i];
        final nome = itemRascunho.nomeIngrediente.trim();
        final normalizado = NormalizadorIngredientes.normalizar(nome);

        // Obter ou criar ingrediente
        final existentes = await txn.query(
          'ingrediente',
          where: 'nome_normalizado = ?',
          whereArgs: [normalizado],
          limit: 1,
        );

        final String idIngrediente;
        if (existentes.isNotEmpty) {
          idIngrediente = existentes.first['id_ingrediente'] as String;
        } else {
          idIngrediente = uuid.v4();
          await txn.insert('ingrediente', {
            'id_ingrediente': idIngrediente,
            'nome': nome,
            'nome_normalizado': normalizado,
          });
        }

        final idItem = uuid.v4();
        final ordem = i + 1;
        final medidaLimpa = itemRascunho.medida.trim();

        await txn.insert('item_receita', {
          'id_item': idItem,
          'id_versao': idVersao,
          'id_ingrediente': idIngrediente,
          'ordem': ordem,
          'medida': medidaLimpa,
        });

        itensDetalhados.add(ItemReceitaDetalhado(
          idItem: idItem,
          idIngrediente: idIngrediente,
          nomeIngrediente: nome,
          ordem: ordem,
          medida: medidaLimpa,
        ));
      }

      // 4. Inserir Etapas
      final etapasCriadas = <Etapa>[];
      for (int i = 0; i < rascunho.etapas.length; i++) {
        final idEtapa = uuid.v4();
        final ordem = i + 1;
        final instrucao = rascunho.etapas[i].trim();

        await txn.insert('etapa', {
          'id_etapa': idEtapa,
          'id_versao': idVersao,
          'ordem': ordem,
          'instrucao': instrucao,
        });

        etapasCriadas.add(Etapa(
          idEtapa: idEtapa,
          idVersao: idVersao,
          ordem: ordem,
          instrucao: instrucao,
        ));
      }

      return ReceitaCompleta(
        receita: receita,
        versao: versao,
        itens: itensDetalhados,
        etapas: etapasCriadas,
      );
    });
  }

  /// Lista receitas próprias não excluídas do usuário ativo, trazendo a versão mais recente.
  Future<List<ReceitaResumo>> listarReceitasProprias(String idAutor) async {
    if (_usarMemoria) {
      final filtradas = receitasWeb
          .where((r) => r.receita.idAutor == idAutor && r.receita.excluidaEm == null)
          .toList();
      filtradas.sort((a, b) =>
          a.versao.titulo.toLowerCase().compareTo(b.versao.titulo.toLowerCase()));
      return filtradas
          .map((r) => ReceitaResumo(
                idReceita: r.receita.idReceita,
                titulo: r.versao.titulo,
                categoria: r.versao.categoria,
                fotoLocal: r.versao.fotoLocal,
                numeroVersao: r.versao.numeroVersao,
                excluidaEm: r.receita.excluidaEm,
              ))
          .toList();
    }

    final resultados = await _db.rawQuery('''
      SELECT 
        r.id_receita,
        r.excluida_em,
        v.titulo,
        v.categoria,
        v.foto_local,
        v.numero_versao
      FROM receita r
      JOIN versao_receita v ON r.id_receita = v.id_receita
      WHERE r.origem = 'usuario'
        AND r.id_autor = ?
        AND r.excluida_em IS NULL
        AND v.numero_versao = (
          SELECT MAX(v2.numero_versao)
          FROM versao_receita v2
          WHERE v2.id_receita = r.id_receita
        )
      ORDER BY v.titulo COLLATE NOCASE ASC;
    ''', [idAutor]);

    return resultados.map((row) {
      return ReceitaResumo(
        idReceita: row['id_receita'] as String,
        titulo: row['titulo'] as String,
        categoria: row['categoria'] as String,
        fotoLocal: row['foto_local'] as String?,
        numeroVersao: row['numero_versao'] as int,
        excluidaEm: row['excluida_em'] != null
            ? DateTime.parse(row['excluida_em'] as String).toUtc()
            : null,
      );
    }).toList();
  }

  /// Obtém a versão mais recente de uma receita (própria do autor ou externa associada ao usuário).
  Future<ReceitaCompleta?> obterReceitaPorId({
    required String idReceita,
    String? idAutor,
    String? idUsuario,
  }) async {
    final usuarioId = idUsuario ?? idAutor ?? '';

    if (_usarMemoria) {
      final encontradas = receitasWeb.where((r) =>
          r.receita.idReceita == idReceita &&
          r.receita.excluidaEm == null &&
          ((r.receita.origem == 'usuario' && r.receita.idAutor == usuarioId) ||
              (r.receita.origem == 'themealdb' &&
                  receitaExternaAssociadaAoUsuario(usuarioId, idReceita))));
      if (encontradas.isEmpty) return null;
      return encontradas.first;
    }

    final receitas = await _db.rawQuery('''
      SELECT r.* FROM receita r
      WHERE r.id_receita = ? AND r.excluida_em IS NULL
        AND (
          (r.origem = 'usuario' AND r.id_autor = ?)
          OR
          (r.origem = 'themealdb' AND EXISTS (
            SELECT 1 FROM receita_externa_usuario reu
            WHERE reu.id_receita = r.id_receita AND reu.id_usuario = ?
          ))
        )
      LIMIT 1;
    ''', [idReceita, usuarioId, usuarioId]);
    if (receitas.isEmpty) return null;

    final receita = Receita.fromMap(receitas.first);

    // Versão mais recente
    final versoes = await _db.query(
      'versao_receita',
      where: 'id_receita = ?',
      whereArgs: [idReceita],
      orderBy: 'numero_versao DESC',
      limit: 1,
    );
    if (versoes.isEmpty) return null;

    final versao = VersaoReceita.fromMap(versoes.first);

    // Itens da versão com nome do ingrediente
    final itensRaw = await _db.rawQuery('''
      SELECT 
        i.id_item,
        i.id_ingrediente,
        i.ordem,
        i.medida,
        ing.nome AS nome_ingrediente
      FROM item_receita i
      JOIN ingrediente ing ON i.id_ingrediente = ing.id_ingrediente
      WHERE i.id_versao = ?
      ORDER BY i.ordem ASC;
    ''', [versao.idVersao]);

    final itens = itensRaw.map((r) => ItemReceitaDetalhado(
      idItem: r['id_item'] as String,
      idIngrediente: r['id_ingrediente'] as String,
      nomeIngrediente: r['nome_ingrediente'] as String,
      ordem: r['ordem'] as int,
      medida: r['medida'] as String,
    )).toList();

    // Etapas da versão ordenadas
    final etapasRaw = await _db.query(
      'etapa',
      where: 'id_versao = ?',
      whereArgs: [versao.idVersao],
      orderBy: 'ordem ASC',
    );
    final etapas = etapasRaw.map((e) => Etapa.fromMap(e)).toList();

    return ReceitaCompleta(
      receita: receita,
      versao: versao,
      itens: itens,
      etapas: etapas,
    );
  }

  /// Salva uma cópia local de receita externa da TheMealDB associada ao usuário ativo.
  Future<ReceitaCompleta> salvarCopiaExterna({
    required String idUsuario,
    required FichaTheMealDb ficha,
  }) async {
    const uuid = Uuid();
    final agora = DateTime.now().toUtc();

    if (_usarMemoria) {
      final index = _receitasWeb.indexWhere(
        (r) => r.receita.origem == 'themealdb' && r.receita.idThemealdb == ficha.idMeal,
      );

      final ReceitaCompleta completa;
      if (index == -1) {
        final idReceita = 'rec_ext_${ficha.idMeal}';
        final idVersao = 'ver_ext_${ficha.idMeal}_v1';
        final rec = Receita(
          idReceita: idReceita,
          idAutor: null,
          origem: 'themealdb',
          idThemealdb: ficha.idMeal,
          visibilidade: 'publica',
          estadoModeracao: 'liberada',
        );
        final versao = VersaoReceita(
          idVersao: idVersao,
          idReceita: idReceita,
          numeroVersao: 1,
          titulo: ficha.strMeal,
          categoria: ficha.categoria,
          fotoRemota: ficha.fotoRemota,
        );
        final itens = ficha.ingredientes
            .map((ing) => ItemReceitaDetalhado(
                  idItem: uuid.v4(),
                  idIngrediente: uuid.v4(),
                  nomeIngrediente: ing.nome,
                  ordem: ing.ordem,
                  medida: ing.medida,
                ))
            .toList();
        final listaEtapas = QuebradorInstrucoes.dividirEmEtapas(ficha.instrucoes);
        final etapas = <Etapa>[];
        for (int i = 0; i < listaEtapas.length; i++) {
          etapas.add(
            Etapa(
              idEtapa: uuid.v4(),
              idVersao: idVersao,
              ordem: i + 1,
              instrucao: listaEtapas[i],
            ),
          );
        }
        completa = ReceitaCompleta(
          receita: rec,
          versao: versao,
          itens: itens,
          etapas: etapas,
        );
        _receitasWeb.add(completa);
      } else {
        final existente = _receitasWeb[index];
        final listaEtapas = QuebradorInstrucoes.dividirEmEtapas(ficha.instrucoes);
        bool conteudoMudou = false;
        if (existente.versao.titulo != ficha.strMeal ||
            existente.versao.categoria != ficha.categoria ||
            existente.versao.fotoRemota != ficha.fotoRemota ||
            existente.etapas.length != listaEtapas.length ||
            existente.itens.length != ficha.ingredientes.length) {
          conteudoMudou = true;
        } else {
          for (int i = 0; i < listaEtapas.length; i++) {
            if (existente.etapas[i].instrucao != listaEtapas[i]) {
              conteudoMudou = true;
              break;
            }
          }
          if (!conteudoMudou) {
            for (int i = 0; i < existente.itens.length; i++) {
              if (existente.itens[i].nomeIngrediente.toLowerCase() !=
                      ficha.ingredientes[i].nome.toLowerCase() ||
                  existente.itens[i].medida != ficha.ingredientes[i].medida) {
                conteudoMudou = true;
                break;
              }
            }
          }
        }

        if (conteudoMudou) {
          final novaVersaoNum = existente.versao.numeroVersao + 1;
          final idNovaVersao = uuid.v4();
          final novaVersao = VersaoReceita(
            idVersao: idNovaVersao,
            idReceita: existente.receita.idReceita,
            numeroVersao: novaVersaoNum,
            titulo: ficha.strMeal,
            categoria: ficha.categoria,
            fotoRemota: ficha.fotoRemota,
          );
          final novosItens = ficha.ingredientes
              .map((ing) => ItemReceitaDetalhado(
                    idItem: uuid.v4(),
                    idIngrediente: uuid.v4(),
                    nomeIngrediente: ing.nome,
                    ordem: ing.ordem,
                    medida: ing.medida,
                  ))
              .toList();
          final novasEtapas = <Etapa>[];
          for (int i = 0; i < listaEtapas.length; i++) {
            novasEtapas.add(
              Etapa(
                idEtapa: uuid.v4(),
                idVersao: idNovaVersao,
                ordem: i + 1,
                instrucao: listaEtapas[i],
              ),
            );
          }
          completa = ReceitaCompleta(
            receita: existente.receita,
            versao: novaVersao,
            itens: novosItens,
            etapas: novasEtapas,
          );
          _receitasWeb[index] = completa;
        } else {
          completa = existente;
        }
      }

      final jaAssociado = _receitasExternasUsuarioWeb.any(
        (m) =>
            m['id_usuario'] == idUsuario &&
            m['id_receita'] == completa.receita.idReceita,
      );
      if (!jaAssociado) {
        _receitasExternasUsuarioWeb.add({
          'id_usuario': idUsuario,
          'id_receita': completa.receita.idReceita,
          'salvo_em': agora,
        });
      }
      return completa;
    }

    return await _db.transaction<ReceitaCompleta>((txn) async {
      final recRows = await txn.query(
        'receita',
        where: "origem = 'themealdb' AND id_themealdb = ?",
        whereArgs: [ficha.idMeal],
        limit: 1,
      );

      final String idReceita;
      final VersaoReceita versaoAtiva;
      final List<ItemReceitaDetalhado> itensAtivos;
      final List<Etapa> etapasAtivas;
      final Receita receitaEntity;

      if (recRows.isEmpty) {
        idReceita = uuid.v4();
        await txn.insert('receita', {
          'id_receita': idReceita,
          'id_autor': null,
          'origem': 'themealdb',
          'id_themealdb': ficha.idMeal,
          'visibilidade': 'publica',
          'estado_moderacao': 'liberada',
          'excluida_em': null,
        });

        receitaEntity = Receita(
          idReceita: idReceita,
          idAutor: null,
          origem: 'themealdb',
          idThemealdb: ficha.idMeal,
          visibilidade: 'publica',
          estadoModeracao: 'liberada',
        );

        final idVersao = uuid.v4();
        await txn.insert('versao_receita', {
          'id_versao': idVersao,
          'id_receita': idReceita,
          'numero_versao': 1,
          'titulo': ficha.strMeal,
          'categoria': ficha.categoria,
          'foto_local': null,
          'foto_remota': ficha.fotoRemota,
        });

        versaoAtiva = VersaoReceita(
          idVersao: idVersao,
          idReceita: idReceita,
          numeroVersao: 1,
          titulo: ficha.strMeal,
          categoria: ficha.categoria,
          fotoRemota: ficha.fotoRemota,
        );

        itensAtivos = [];
        for (final item in ficha.ingredientes) {
          final normalizado = NormalizadorIngredientes.normalizar(item.nome);
          final existentes = await txn.query(
            'ingrediente',
            columns: ['id_ingrediente'],
            where: 'nome_normalizado = ?',
            whereArgs: [normalizado],
            limit: 1,
          );
          final String idIngrediente;
          if (existentes.isNotEmpty) {
            idIngrediente = existentes.first['id_ingrediente'] as String;
          } else {
            idIngrediente = uuid.v4();
            await txn.insert('ingrediente', {
              'id_ingrediente': idIngrediente,
              'nome': item.nome,
              'nome_normalizado': normalizado,
            });
          }
          final idItem = uuid.v4();
          await txn.insert('item_receita', {
            'id_item': idItem,
            'id_versao': idVersao,
            'id_ingrediente': idIngrediente,
            'ordem': item.ordem,
            'medida': item.medida,
          });
          itensAtivos.add(ItemReceitaDetalhado(
            idItem: idItem,
            idIngrediente: idIngrediente,
            nomeIngrediente: item.nome,
            ordem: item.ordem,
            medida: item.medida,
          ));
        }

        final listaEtapas = QuebradorInstrucoes.dividirEmEtapas(ficha.instrucoes);
        etapasAtivas = [];
        for (int i = 0; i < listaEtapas.length; i++) {
          final idEtapa = uuid.v4();
          final ordem = i + 1;
          final instrucao = listaEtapas[i];
          await txn.insert('etapa', {
            'id_etapa': idEtapa,
            'id_versao': idVersao,
            'ordem': ordem,
            'instrucao': instrucao,
          });
          etapasAtivas.add(Etapa(
            idEtapa: idEtapa,
            idVersao: idVersao,
            ordem: ordem,
            instrucao: instrucao,
          ));
        }
      } else {
        idReceita = recRows.first['id_receita'] as String;
        receitaEntity = Receita.fromMap(recRows.first);

        final versoesRows = await txn.query(
          'versao_receita',
          where: 'id_receita = ?',
          whereArgs: [idReceita],
          orderBy: 'numero_versao DESC',
          limit: 1,
        );
        final versaoAtual = VersaoReceita.fromMap(versoesRows.first);

        final etapasRows = await txn.query(
          'etapa',
          where: 'id_versao = ?',
          whereArgs: [versaoAtual.idVersao],
          orderBy: 'ordem ASC',
        );
        final etapasExistentes = etapasRows.map((e) => Etapa.fromMap(e)).toList();

        final itensRaw = await txn.rawQuery('''
          SELECT i.id_item, i.id_ingrediente, i.ordem, i.medida, ing.nome AS nome_ingrediente
          FROM item_receita i
          JOIN ingrediente ing ON i.id_ingrediente = ing.id_ingrediente
          WHERE i.id_versao = ?
          ORDER BY i.ordem ASC
        ''', [versaoAtual.idVersao]);
        final itensExistentes = itensRaw
            .map((r) => ItemReceitaDetalhado(
                  idItem: r['id_item'] as String,
                  idIngrediente: r['id_ingrediente'] as String,
                  nomeIngrediente: r['nome_ingrediente'] as String,
                  ordem: r['ordem'] as int,
                  medida: r['medida'] as String,
                ))
            .toList();

        final listaEtapas = QuebradorInstrucoes.dividirEmEtapas(ficha.instrucoes);
        bool mudou = false;
        if (versaoAtual.titulo != ficha.strMeal ||
            versaoAtual.categoria != ficha.categoria ||
            versaoAtual.fotoRemota != ficha.fotoRemota ||
            etapasExistentes.length != listaEtapas.length ||
            itensExistentes.length != ficha.ingredientes.length) {
          mudou = true;
        } else {
          for (int i = 0; i < listaEtapas.length; i++) {
            if (etapasExistentes[i].instrucao != listaEtapas[i]) {
              mudou = true;
              break;
            }
          }
          if (!mudou) {
            for (int i = 0; i < itensExistentes.length; i++) {
              if (itensExistentes[i].nomeIngrediente.toLowerCase() !=
                      ficha.ingredientes[i].nome.toLowerCase() ||
                  itensExistentes[i].medida != ficha.ingredientes[i].medida) {
                mudou = true;
                break;
              }
            }
          }
        }

        if (mudou) {
          final novoNumero = versaoAtual.numeroVersao + 1;
          final idNovaVersao = uuid.v4();
          await txn.insert('versao_receita', {
            'id_versao': idNovaVersao,
            'id_receita': idReceita,
            'numero_versao': novoNumero,
            'titulo': ficha.strMeal,
            'categoria': ficha.categoria,
            'foto_local': null,
            'foto_remota': ficha.fotoRemota,
          });
          versaoAtiva = VersaoReceita(
            idVersao: idNovaVersao,
            idReceita: idReceita,
            numeroVersao: novoNumero,
            titulo: ficha.strMeal,
            categoria: ficha.categoria,
            fotoRemota: ficha.fotoRemota,
          );

          itensAtivos = [];
          for (final item in ficha.ingredientes) {
            final normalizado = NormalizadorIngredientes.normalizar(item.nome);
            final existentes = await txn.query(
              'ingrediente',
              columns: ['id_ingrediente'],
              where: 'nome_normalizado = ?',
              whereArgs: [normalizado],
              limit: 1,
            );
            final String idIngrediente;
            if (existentes.isNotEmpty) {
              idIngrediente = existentes.first['id_ingrediente'] as String;
            } else {
              idIngrediente = uuid.v4();
              await txn.insert('ingrediente', {
                'id_ingrediente': idIngrediente,
                'nome': item.nome,
                'nome_normalizado': normalizado,
              });
            }
            final idItem = uuid.v4();
            await txn.insert('item_receita', {
              'id_item': idItem,
              'id_versao': idNovaVersao,
              'id_ingrediente': idIngrediente,
              'ordem': item.ordem,
              'medida': item.medida,
            });
            itensAtivos.add(ItemReceitaDetalhado(
              idItem: idItem,
              idIngrediente: idIngrediente,
              nomeIngrediente: item.nome,
              ordem: item.ordem,
              medida: item.medida,
            ));
          }

          etapasAtivas = [];
          for (int i = 0; i < listaEtapas.length; i++) {
            final idEtapa = uuid.v4();
            final ordem = i + 1;
            final instrucao = listaEtapas[i];
            await txn.insert('etapa', {
              'id_etapa': idEtapa,
              'id_versao': idNovaVersao,
              'ordem': ordem,
              'instrucao': instrucao,
            });
            etapasAtivas.add(Etapa(
              idEtapa: idEtapa,
              idVersao: idNovaVersao,
              ordem: ordem,
              instrucao: instrucao,
            ));
          }
        } else {
          versaoAtiva = versaoAtual;
          itensAtivos = itensExistentes;
          etapasAtivas = etapasExistentes;
        }
      }

      await txn.insert(
        'receita_externa_usuario',
        {
          'id_usuario': idUsuario,
          'id_receita': idReceita,
          'salvo_em': agora.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      return ReceitaCompleta(
        receita: receitaEntity,
        versao: versaoAtiva,
        itens: itensAtivos,
        etapas: etapasAtivas,
      );
    });
  }

  /// Lista receitas externas salvas/copiadas pelo usuário ativo.
  Future<List<ReceitaResumo>> listarReceitasExternasSalvas(String idUsuario) async {
    if (_usarMemoria) {
      final associacoes = _receitasExternasUsuarioWeb
          .where((m) => m['id_usuario'] == idUsuario)
          .toList();

      final lista = <ReceitaResumo>[];
      for (final assoc in associacoes) {
        final rec = _receitasWeb
            .where((r) =>
                r.receita.idReceita == assoc['id_receita'] &&
                r.receita.excluidaEm == null)
            .firstOrNull;
        if (rec != null) {
          lista.add(ReceitaResumo(
            idReceita: rec.receita.idReceita,
            titulo: rec.versao.titulo,
            categoria: rec.versao.categoria,
            fotoLocal: rec.versao.fotoLocal,
            fotoRemota: rec.versao.fotoRemota,
            numeroVersao: rec.versao.numeroVersao,
            origem: rec.receita.origem,
            idThemealdb: rec.receita.idThemealdb,
            salvoEm: assoc['salvo_em'] as DateTime?,
          ));
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
        r.id_receita,
        r.id_themealdb,
        r.origem,
        r.excluida_em,
        reu.salvo_em,
        v.titulo,
        v.categoria,
        v.foto_local,
        v.foto_remota,
        v.numero_versao
      FROM receita_externa_usuario reu
      JOIN receita r ON reu.id_receita = r.id_receita
      JOIN versao_receita v ON r.id_receita = v.id_receita
      WHERE reu.id_usuario = ?
        AND r.excluida_em IS NULL
        AND v.numero_versao = (
          SELECT MAX(v2.numero_versao)
          FROM versao_receita v2
          WHERE v2.id_receita = r.id_receita
        )
      ORDER BY reu.salvo_em DESC, r.id_receita ASC;
    ''', [idUsuario]);

    return resultados.map((row) {
      return ReceitaResumo(
        idReceita: row['id_receita'] as String,
        titulo: row['titulo'] as String,
        categoria: row['categoria'] as String,
        fotoLocal: row['foto_local'] as String?,
        fotoRemota: row['foto_remota'] as String?,
        numeroVersao: row['numero_versao'] as int,
        origem: (row['origem'] as String?) ?? 'themealdb',
        idThemealdb: row['id_themealdb'] as String?,
        salvoEm: row['salvo_em'] != null
            ? DateTime.parse(row['salvo_em'] as String).toUtc()
            : null,
      );
    }).toList();
  }

  /// Cria uma nova versão da receita, preservando integralmente a versão anterior.
  Future<ReceitaCompleta> criarNovaVersao({
    required String idReceita,
    required String idAutor,
    required RascunhoReceita rascunho,
    String? caminhoFotoRelativo,
  }) async {
    const uuid = Uuid();
    final categoriaLimpa = (rascunho.categoria != null && rascunho.categoria!.trim().isNotEmpty)
        ? rascunho.categoria!.trim()
        : 'Sem categoria';

    if (_usarMemoria) {
      final index = _receitasWeb.indexWhere((r) =>
          r.receita.idReceita == idReceita &&
          r.receita.idAutor == idAutor &&
          r.receita.excluidaEm == null);
      if (index == -1) {
        throw StateError('Receita não encontrada ou sem permissão de edição.');
      }
      final antiga = _receitasWeb[index];
      final novaVersaoNumero = antiga.versao.numeroVersao + 1;
      final idNovaVersao = uuid.v4();
      final novaVersao = VersaoReceita(
        idVersao: idNovaVersao,
        idReceita: idReceita,
        numeroVersao: novaVersaoNumero,
        titulo: rascunho.titulo.trim(),
        categoria: categoriaLimpa,
        fotoLocal: caminhoFotoRelativo,
      );
      final novosItens = <ItemReceitaDetalhado>[];
      for (int i = 0; i < rascunho.itens.length; i++) {
        final it = rascunho.itens[i];
        novosItens.add(ItemReceitaDetalhado(
          idItem: uuid.v4(),
          idIngrediente: uuid.v4(),
          nomeIngrediente: it.nomeIngrediente.trim(),
          ordem: i + 1,
          medida: it.medida.trim(),
        ));
      }
      final novasEtapas = <Etapa>[];
      for (int i = 0; i < rascunho.etapas.length; i++) {
        novasEtapas.add(Etapa(
          idEtapa: uuid.v4(),
          idVersao: idNovaVersao,
          ordem: i + 1,
          instrucao: rascunho.etapas[i].trim(),
        ));
      }
      final atualizada = ReceitaCompleta(
        receita: antiga.receita,
        versao: novaVersao,
        itens: novosItens,
        etapas: novasEtapas,
      );
      _receitasWeb[index] = atualizada;
      return atualizada;
    }

    return await _db.transaction((txn) async {
      // 1. Confirmar existência e autoria
      final receitas = await txn.query(
        'receita',
        where: 'id_receita = ? AND id_autor = ? AND excluida_em IS NULL',
        whereArgs: [idReceita, idAutor],
        limit: 1,
      );
      if (receitas.isEmpty) {
        throw StateError('Receita não encontrada ou sem permissão de edição.');
      }
      final receita = Receita.fromMap(receitas.first);

      // 2. Determinar próximo número de versão
      final maxVersaoResult = await txn.rawQuery(
        'SELECT MAX(numero_versao) as max_v FROM versao_receita WHERE id_receita = ?',
        [idReceita],
      );
      final int proximaVersao = ((maxVersaoResult.first['max_v'] as int?) ?? 0) + 1;

      final idNovaVersao = uuid.v4();
      final novaVersao = VersaoReceita(
        idVersao: idNovaVersao,
        idReceita: idReceita,
        numeroVersao: proximaVersao,
        titulo: rascunho.titulo.trim(),
        categoria: categoriaLimpa,
        fotoLocal: caminhoFotoRelativo,
      );
      await txn.insert('versao_receita', novaVersao.toMap());

      // 3. Inserir novos itens
      final itensDetalhados = <ItemReceitaDetalhado>[];
      for (int i = 0; i < rascunho.itens.length; i++) {
        final itemRascunho = rascunho.itens[i];
        final nome = itemRascunho.nomeIngrediente.trim();
        final normalizado = NormalizadorIngredientes.normalizar(nome);

        final existentes = await txn.query(
          'ingrediente',
          where: 'nome_normalizado = ?',
          whereArgs: [normalizado],
          limit: 1,
        );

        final String idIngrediente;
        if (existentes.isNotEmpty) {
          idIngrediente = existentes.first['id_ingrediente'] as String;
        } else {
          idIngrediente = uuid.v4();
          await txn.insert('ingrediente', {
            'id_ingrediente': idIngrediente,
            'nome': nome,
            'nome_normalizado': normalizado,
          });
        }

        final idItem = uuid.v4();
        final ordem = i + 1;
        final medida = itemRascunho.medida.trim();

        await txn.insert('item_receita', {
          'id_item': idItem,
          'id_versao': idNovaVersao,
          'id_ingrediente': idIngrediente,
          'ordem': ordem,
          'medida': medida,
        });

        itensDetalhados.add(ItemReceitaDetalhado(
          idItem: idItem,
          idIngrediente: idIngrediente,
          nomeIngrediente: nome,
          ordem: ordem,
          medida: medida,
        ));
      }

      // 4. Inserir novas etapas
      final etapasCriadas = <Etapa>[];
      for (int i = 0; i < rascunho.etapas.length; i++) {
        final idEtapa = uuid.v4();
        final ordem = i + 1;
        final instrucao = rascunho.etapas[i].trim();

        await txn.insert('etapa', {
          'id_etapa': idEtapa,
          'id_versao': idNovaVersao,
          'ordem': ordem,
          'instrucao': instrucao,
        });

        etapasCriadas.add(Etapa(
          idEtapa: idEtapa,
          idVersao: idNovaVersao,
          ordem: ordem,
          instrucao: instrucao,
        ));
      }

      return ReceitaCompleta(
        receita: receita,
        versao: novaVersao,
        itens: itensDetalhados,
        etapas: etapasCriadas,
      );
    });
  }

  /// Exclui logicamente a receita preenchendo excluida_em, sem deletar registros físicos.
  /// Remove vínculos de favorito na mesma transação/operação para garantir integridade.
  Future<bool> excluirReceitaLogica({
    required String idReceita,
    required String idAutor,
  }) async {
    if (_usarMemoria) {
      final index = _receitasWeb.indexWhere((r) =>
          r.receita.idReceita == idReceita &&
          r.receita.idAutor == idAutor &&
          r.receita.excluidaEm == null);
      if (index == -1) return false;
      final antiga = _receitasWeb[index];
      final excluida = Receita(
        idReceita: antiga.receita.idReceita,
        idAutor: antiga.receita.idAutor,
        origem: antiga.receita.origem,
        idThemealdb: antiga.receita.idThemealdb,
        visibilidade: antiga.receita.visibilidade,
        estadoModeracao: antiga.receita.estadoModeracao,
        excluidaEm: DateTime.now().toUtc(),
      );
      _receitasWeb[index] = ReceitaCompleta(
        receita: excluida,
        versao: antiga.versao,
        itens: antiga.itens,
        etapas: antiga.etapas,
      );
      RepositorioFavoritos.removerFavoritoEmMemoria(idReceita);
      return true;
    }

    final agora = DateTime.now().toUtc().toIso8601String();
    return await _db.transaction<bool>((txn) async {
      final linhasAfetadas = await txn.update(
        'receita',
        {'excluida_em': agora},
        where: 'id_receita = ? AND id_autor = ? AND excluida_em IS NULL',
        whereArgs: [idReceita, idAutor],
      );
      if (linhasAfetadas > 0) {
        await txn.delete(
          'favorito',
          where: 'id_receita = ?',
          whereArgs: [idReceita],
        );
        return true;
      }
      return false;
    });
  }
}
