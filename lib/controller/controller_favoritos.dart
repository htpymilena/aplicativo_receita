import 'package:flutter/foundation.dart';
import '../model/repositorios/banco_dados.dart';
import '../model/repositorios/repositorio_favoritos.dart';
import '../model/repositorios/repositorio_receitas.dart';
import '../model/repositorios/repositorio_themealdb.dart';
import '../model/servicos/servico_traducao.dart';

/// Controller para gerenciar e sincronizar receitas favoritas do usuário ativo.
class ControllerFavoritos extends ChangeNotifier {
  final RepositorioFavoritos repositorio;
  final RepositorioReceitas repositorioReceitas;
  final RepositorioTheMealDb repositorioTheMealDb;
  final BancoDados bancoDados;
  final ServicoTraducao servicoTraducao;

  ControllerFavoritos({
    RepositorioFavoritos? repositorio,
    RepositorioReceitas? repositorioReceitas,
    RepositorioTheMealDb? repositorioTheMealDb,
    BancoDados? bancoDados,
    ServicoTraducao? servicoTraducao,
  })  : repositorio = repositorio ?? RepositorioFavoritos(),
        repositorioReceitas = repositorioReceitas ?? RepositorioReceitas(),
        repositorioTheMealDb = repositorioTheMealDb ?? RepositorioTheMealDb(),
        bancoDados = bancoDados ?? BancoDados.instancia,
        servicoTraducao = servicoTraducao ?? ServicoTraducao();

  bool carregando = false;
  String? erro;
  String? _idUsuarioAtivo;

  List<ReceitaResumo> favoritos = [];
  Set<String> _idsFavoritos = {};

  // Bloqueio de escrita concorrente por receita
  final Set<String> _escritasPendentes = {};

  bool isFavorito(String idReceita) => _idsFavoritos.contains(idReceita);
  bool isFavoritoPorIdThemealdb(String idThemealdb) =>
      favoritos.any((r) => r.idThemealdb == idThemealdb);
  bool estaProcessando(String idReceita) => _escritasPendentes.contains(idReceita);

  String? get idUsuarioAtivo => _idUsuarioAtivo;

  Future<String> _obterIdUsuarioAtivo() async {
    if (_idUsuarioAtivo != null) return _idUsuarioAtivo!;
    final usuario = await bancoDados.obterOuCriarUsuarioProvisorio();
    _idUsuarioAtivo = usuario.idUsuario;
    return _idUsuarioAtivo!;
  }

  /// Define explicitamente o usuário ativo e recarrega os favoritos.
  Future<void> trocarUsuario(String novoIdUsuario) async {
    _idUsuarioAtivo = novoIdUsuario;
    _idsFavoritos.clear();
    favoritos.clear();
    _escritasPendentes.clear();
    erro = null;
    await carregarFavoritos();
  }

  /// Carrega os favoritos do usuário ativo a partir do repositório.
  Future<void> carregarFavoritos() async {
    carregando = true;
    erro = null;
    notifyListeners();

    try {
      final idUsuario = await _obterIdUsuarioAtivo();
      favoritos = await repositorio.listarFavoritos(idUsuario);
      _idsFavoritos = favoritos.map((r) => r.idReceita).toSet();
    } catch (e) {
      erro = 'Não foi possível carregar os favoritos: $e';
    } finally {
      carregando = false;
      notifyListeners();
    }
  }

  /// Alterna o status de favorito com atualização otimista, bloqueio por receita e reversão em falha.
  Future<bool> alternarFavorito(String idReceita) async {
    // Bloqueia escrita concorrente para a mesma receita
    if (_escritasPendentes.contains(idReceita)) {
      return false;
    }

    _escritasPendentes.add(idReceita);
    final estavaFavorito = _idsFavoritos.contains(idReceita);
    erro = null;

    // Atualização otimista
    if (estavaFavorito) {
      _idsFavoritos.remove(idReceita);
      favoritos.removeWhere((r) => r.idReceita == idReceita);
    } else {
      _idsFavoritos.add(idReceita);
    }
    notifyListeners();

    try {
      final idUsuario = await _obterIdUsuarioAtivo();
      if (estavaFavorito) {
        await repositorio.removerFavorito(
          idUsuario: idUsuario,
          idReceita: idReceita,
        );
      } else {
        await repositorio.adicionarFavorito(
          idUsuario: idUsuario,
          idReceita: idReceita,
        );
      }

      favoritos = await repositorio.listarFavoritos(idUsuario);
      _idsFavoritos = favoritos.map((r) => r.idReceita).toSet();
      return true;
    } catch (e) {
      // Reverte estado anterior em falha
      if (estavaFavorito) {
        _idsFavoritos.add(idReceita);
      } else {
        _idsFavoritos.remove(idReceita);
      }
      erro = 'Não foi possível alterar favorito: $e';
      return false;
    } finally {
      _escritasPendentes.remove(idReceita);
      notifyListeners();
    }
  }

  /// Alterna favorito diretamente a partir de um prato da TheMealDB.
  /// Se já for favorito, remove.
  /// Se não for, busca a ficha completa via API se necessário, salva a cópia transacionalmente e adiciona o favorito.
  Future<bool> alternarFavoritoTheMealDb(String idMeal) async {
    final favoritoExistente = favoritos.where((r) => r.idThemealdb == idMeal).firstOrNull;
    if (favoritoExistente != null) {
      return await alternarFavorito(favoritoExistente.idReceita);
    }

    if (_escritasPendentes.contains(idMeal)) {
      return false;
    }
    _escritasPendentes.add(idMeal);
    erro = null;
    notifyListeners();

    try {
      final idUsuario = await _obterIdUsuarioAtivo();

      // Verifica se já temos cópia local salva para o usuário
      final salvas = await repositorioReceitas.listarReceitasExternasSalvas(idUsuario);
      final copiaExistente = salvas.where((r) => r.idThemealdb == idMeal).firstOrNull;

      final String idReceita;
      if (copiaExistente != null) {
        idReceita = copiaExistente.idReceita;
      } else {
        // Busca a ficha completa da TheMealDB
        final ficha = await repositorioTheMealDb.obterDetalhesPorId(idMeal);
        if (ficha == null) {
          throw StateError('Não foi possível obter detalhes da receita TheMealDB.');
        }
        final fichaTraduzida = await servicoTraducao.traduzirFichaParaPortugues(ficha);
        final copia = await repositorioReceitas.salvarCopiaExterna(
          idUsuario: idUsuario,
          ficha: fichaTraduzida,
        );
        idReceita = copia.receita.idReceita;
      }

      await repositorio.adicionarFavorito(
        idUsuario: idUsuario,
        idReceita: idReceita,
      );

      favoritos = await repositorio.listarFavoritos(idUsuario);
      _idsFavoritos = favoritos.map((r) => r.idReceita).toSet();
      return true;
    } catch (e) {
      erro = 'Não foi possível favoritar a receita externa: $e';
      return false;
    } finally {
      _escritasPendentes.remove(idMeal);
      notifyListeners();
    }
  }
}
