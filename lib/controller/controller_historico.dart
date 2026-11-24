import 'package:flutter/foundation.dart';
import '../model/repositorios/banco_dados.dart';
import '../model/repositorios/repositorio_preparos.dart';

/// Controller para coordenar as consultas de Histórico e faixas do Início.
class ControllerHistorico extends ChangeNotifier {
  final RepositorioPreparos repositorio;
  final BancoDados bancoDados;

  ControllerHistorico({
    RepositorioPreparos? repositorio,
    BancoDados? bancoDados,
  })  : repositorio = repositorio ?? RepositorioPreparos(),
        bancoDados = bancoDados ?? BancoDados.instancia;

  bool carregando = false;
  String? erro;
  List<PreparoResumo> emAndamento = [];
  List<PreparoResumo> concluidos = [];
  PreparoDetalhado? detalhePreparo;

  Future<String> _obterIdUsuarioAtivo() async {
    final usuario = await bancoDados.obterOuCriarUsuarioProvisorio();
    return usuario.idUsuario;
  }

  /// Carrega as listas de preparos em andamento e concluídos do usuário ativo.
  Future<void> carregarTudo() async {
    carregando = true;
    erro = null;
    notifyListeners();

    try {
      final idUsuario = await _obterIdUsuarioAtivo();
      final resultados = await Future.wait([
        repositorio.listarPreparosEmAndamento(idUsuario: idUsuario),
        repositorio.listarPreparosConcluidos(idUsuario: idUsuario),
      ]);
      emAndamento = resultados[0];
      concluidos = resultados[1];
    } catch (e) {
      erro = 'Erro ao carregar histórico: $e';
    } finally {
      carregando = false;
      notifyListeners();
    }
  }

  /// Carrega o detalhe de um preparo para a tela de detalhes do histórico.
  Future<void> carregarDetalhe(String idPreparo) async {
    carregando = true;
    erro = null;
    notifyListeners();

    try {
      final idUsuario = await _obterIdUsuarioAtivo();
      detalhePreparo = await repositorio.obterPreparoDetalhado(
        idPreparo: idPreparo,
        idUsuario: idUsuario,
      );
      if (detalhePreparo == null) {
        erro = 'Registro histórico não encontrado.';
      }
    } catch (e) {
      erro = 'Erro ao carregar detalhes do preparo: $e';
    } finally {
      carregando = false;
      notifyListeners();
    }
  }

  /// Atualiza ou insere a nota pessoal de um preparo concluído.
  Future<bool> atualizarAvaliacao(String idPreparo, int estrelas) async {
    try {
      final idUsuario = await _obterIdUsuarioAtivo();
      final aval = await repositorio.salvarAvaliacao(
        idPreparo: idPreparo,
        idUsuario: idUsuario,
        estrelas: estrelas,
      );

      // Atualiza detalhe se estiver carregado
      if (detalhePreparo != null && detalhePreparo!.preparo.idPreparo == idPreparo) {
        detalhePreparo = PreparoDetalhado(
          preparo: detalhePreparo!.preparo,
          versao: detalhePreparo!.versao,
          receita: detalhePreparo!.receita,
          conferencias: detalhePreparo!.conferencias,
          etapas: detalhePreparo!.etapas,
          avaliacao: aval,
        );
      }

      // Atualiza lista de concluídos em memória
      final idx = concluidos.indexWhere((p) => p.idPreparo == idPreparo);
      if (idx != -1) {
        final antigo = concluidos[idx];
        concluidos[idx] = PreparoResumo(
          idPreparo: antigo.idPreparo,
          idReceita: antigo.idReceita,
          idVersao: antigo.idVersao,
          tituloReceita: antigo.tituloReceita,
          fotoLocal: antigo.fotoLocal,
          iniciadoEm: antigo.iniciadoEm,
          concluidoEm: antigo.concluidoEm,
          ordemEtapaAtual: antigo.ordemEtapaAtual,
          totalEtapas: antigo.totalEtapas,
          estrelas: estrelas,
          receitaExcluida: antigo.receitaExcluida,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      erro = 'Erro ao salvar avaliação: $e';
      notifyListeners();
      return false;
    }
  }
}
