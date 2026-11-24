import 'dart:async';
import 'package:flutter/foundation.dart';
import '../model/entidades/entidades.dart';
import '../model/repositorios/banco_dados.dart';
import '../model/repositorios/repositorio_preparos.dart';

/// Controller para gerenciar a sessão ativa de preparo, conferência de ingredientes e etapas.
class ControllerPreparo extends ChangeNotifier {
  final RepositorioPreparos repositorio;
  final BancoDados bancoDados;

  ControllerPreparo({
    RepositorioPreparos? repositorio,
    BancoDados? bancoDados,
  })  : repositorio = repositorio ?? RepositorioPreparos(),
        bancoDados = bancoDados ?? BancoDados.instancia;

  bool iniciando = false;
  bool carregando = false;
  String? erro;
  PreparoDetalhado? preparoAtual;

  // Fila de operações de escrita por item para garantir serialização
  final Map<String, Future<void>> _filasPorItem = {};

  Future<String> _obterIdUsuarioAtivo() async {
    final usuario = await bancoDados.obterOuCriarUsuarioProvisorio();
    return usuario.idUsuario;
  }

  int get totalItens => preparoAtual?.totalItens ?? 0;
  int get totalConferidos => preparoAtual?.totalConferidos ?? 0;
  int get totalTenho => preparoAtual?.totalTenho ?? 0;
  int get totalFalta => preparoAtual?.totalFalta ?? 0;
  bool get temFaltantes => (preparoAtual?.totalFalta ?? 0) > 0;
  int get etapaAtual => preparoAtual?.preparo.ordemEtapaAtual ?? 1;
  int get totalEtapas => preparoAtual?.totalEtapas ?? 0;

  /// Inicia uma nova sessão de preparo com bloqueio de clique duplo/duplicado.
  Future<PreparoDetalhado?> iniciarReceita(String idReceita) async {
    if (iniciando) return null; // Bloqueio contra toque repetido

    iniciando = true;
    erro = null;
    notifyListeners();

    try {
      final idUsuario = await _obterIdUsuarioAtivo();
      preparoAtual = await repositorio.iniciarPreparo(
        idUsuario: idUsuario,
        idReceita: idReceita,
      );
      return preparoAtual;
    } catch (e) {
      erro = 'Erro ao iniciar preparo: $e';
      return null;
    } finally {
      iniciando = false;
      notifyListeners();
    }
  }

  /// Carrega uma sessão de preparo existente para retomada.
  Future<void> carregarPreparo(String idPreparo) async {
    carregando = true;
    erro = null;
    notifyListeners();

    try {
      final idUsuario = await _obterIdUsuarioAtivo();
      preparoAtual = await repositorio.obterPreparoDetalhado(
        idPreparo: idPreparo,
        idUsuario: idUsuario,
      );
      if (preparoAtual == null) {
        erro = 'Preparo não encontrado ou inacessível.';
      }
    } catch (e) {
      erro = 'Erro ao carregar sessão de preparo: $e';
    } finally {
      carregando = false;
      notifyListeners();
    }
  }

  /// Altera o estado de conferência com resposta visual imediata (< 200 ms) e reversão em falha.
  Future<void> alterarConferencia(String idItem, String novoEstado) async {
    if (preparoAtual == null) return;

    final index = preparoAtual!.conferencias.indexWhere((c) => c.idItem == idItem);
    if (index == -1) return;

    final estadoAnterior = preparoAtual!.conferencias[index].estado;
    if (estadoAnterior == novoEstado) return;

    // Atualização otimista imediata na interface
    final confAtualizada = preparoAtual!.conferencias[index].copyWith(estado: novoEstado);
    final novaLista = List<ConferenciaItem>.from(preparoAtual!.conferencias);
    novaLista[index] = confAtualizada;

    preparoAtual = PreparoDetalhado(
      preparo: preparoAtual!.preparo,
      versao: preparoAtual!.versao,
      receita: preparoAtual!.receita,
      conferencias: novaLista,
      etapas: preparoAtual!.etapas,
      avaliacao: preparoAtual!.avaliacao,
    );
    notifyListeners();

    // Serialização de escritas por item
    final operacaoAnterior = _filasPorItem[idItem] ?? Future.value();
    final operacaoAtual = operacaoAnterior.then((_) async {
      try {
        final idUsuario = await _obterIdUsuarioAtivo();
        await repositorio.atualizarConferencia(
          idPreparo: preparoAtual!.preparo.idPreparo,
          idItem: idItem,
          novoEstado: novoEstado,
          idUsuario: idUsuario,
        );
      } catch (e) {
        // Reverte a alteração otimista em caso de erro
        final idxReversao = preparoAtual?.conferencias.indexWhere((c) => c.idItem == idItem) ?? -1;
        if (idxReversao != -1) {
          final listaRevertida = List<ConferenciaItem>.from(preparoAtual!.conferencias);
          listaRevertida[idxReversao] = listaRevertida[idxReversao].copyWith(estado: estadoAnterior);
          preparoAtual = PreparoDetalhado(
            preparo: preparoAtual!.preparo,
            versao: preparoAtual!.versao,
            receita: preparoAtual!.receita,
            conferencias: listaRevertida,
            etapas: preparoAtual!.etapas,
            avaliacao: preparoAtual!.avaliacao,
          );
        }
        erro = 'Erro ao salvar conferência: $e';
        notifyListeners();
      }
    });

    _filasPorItem[idItem] = operacaoAtual;
    await operacaoAtual;
  }

  /// Muda a etapa atual do preparo, persistindo a ordem para retomada.
  Future<void> mudarEtapa(int novaOrdem) async {
    if (preparoAtual == null) return;
    if (novaOrdem < 1 || novaOrdem > totalEtapas) return;

    final pAntigo = preparoAtual!.preparo;
    final pAtualizado = Preparo(
      idPreparo: pAntigo.idPreparo,
      idUsuario: pAntigo.idUsuario,
      idVersao: pAntigo.idVersao,
      iniciadoEm: pAntigo.iniciadoEm,
      concluidoEm: pAntigo.concluidoEm,
      ordemEtapaAtual: novaOrdem,
    );

    preparoAtual = PreparoDetalhado(
      preparo: pAtualizado,
      versao: preparoAtual!.versao,
      receita: preparoAtual!.receita,
      conferencias: preparoAtual!.conferencias,
      etapas: preparoAtual!.etapas,
      avaliacao: preparoAtual!.avaliacao,
    );
    notifyListeners();

    try {
      final idUsuario = await _obterIdUsuarioAtivo();
      await repositorio.atualizarEtapaAtual(
        idPreparo: pAntigo.idPreparo,
        novaOrdem: novaOrdem,
        idUsuario: idUsuario,
      );
    } catch (e) {
      erro = 'Erro ao persistir etapa atual: $e';
      notifyListeners();
    }
  }

  /// Conclui o preparo atual idempotentemente.
  Future<bool> concluirPreparo() async {
    if (preparoAtual == null) return false;

    try {
      final idUsuario = await _obterIdUsuarioAtivo();
      final dataConclusao = await repositorio.concluirPreparo(
        idPreparo: preparoAtual!.preparo.idPreparo,
        idUsuario: idUsuario,
      );

      final p = preparoAtual!.preparo;
      preparoAtual = PreparoDetalhado(
        preparo: Preparo(
          idPreparo: p.idPreparo,
          idUsuario: p.idUsuario,
          idVersao: p.idVersao,
          iniciadoEm: p.iniciadoEm,
          concluidoEm: dataConclusao,
          ordemEtapaAtual: p.ordemEtapaAtual,
        ),
        versao: preparoAtual!.versao,
        receita: preparoAtual!.receita,
        conferencias: preparoAtual!.conferencias,
        etapas: preparoAtual!.etapas,
        avaliacao: preparoAtual!.avaliacao,
      );
      notifyListeners();
      return true;
    } catch (e) {
      erro = 'Erro ao concluir preparo: $e';
      notifyListeners();
      return false;
    }
  }

  /// Salva avaliação pessoal de 1 a 5 estrelas.
  Future<bool> salvarAvaliacao(int estrelas) async {
    if (preparoAtual == null) return false;

    try {
      final idUsuario = await _obterIdUsuarioAtivo();
      final aval = await repositorio.salvarAvaliacao(
        idPreparo: preparoAtual!.preparo.idPreparo,
        idUsuario: idUsuario,
        estrelas: estrelas,
      );

      preparoAtual = PreparoDetalhado(
        preparo: preparoAtual!.preparo,
        versao: preparoAtual!.versao,
        receita: preparoAtual!.receita,
        conferencias: preparoAtual!.conferencias,
        etapas: preparoAtual!.etapas,
        avaliacao: aval,
      );
      notifyListeners();
      return true;
    } catch (e) {
      erro = 'Erro ao registrar avaliação: $e';
      notifyListeners();
      return false;
    }
  }
}
