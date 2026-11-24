import 'package:flutter/foundation.dart';
import '../model/repositorios/banco_dados.dart';
import '../model/repositorios/repositorio_receitas.dart';
import '../model/servicos/gerenciador_fotos.dart';
import '../model/servicos/rascunho_receita.dart';

/// Controller para coordenar as ações de receitas próprias, isolando a View do SQL.
class ControllerReceitas extends ChangeNotifier {
  final RepositorioReceitas repositorio;
  final GerenciadorFotos gerenciadorFotos;
  final BancoDados bancoDados;

  ControllerReceitas({
    RepositorioReceitas? repositorio,
    GerenciadorFotos? gerenciadorFotos,
    BancoDados? bancoDados,
  })  : repositorio = repositorio ?? RepositorioReceitas(),
        gerenciadorFotos = gerenciadorFotos ?? GerenciadorFotos(),
        bancoDados = bancoDados ?? BancoDados.instancia;

  bool carregando = false;
  String? erro;
  List<ReceitaResumo> receitas = [];
  ReceitaCompleta? receitaSelecionada;

  Future<String> _obterIdAutorAtivo() async {
    final usuario = await bancoDados.obterOuCriarUsuarioProvisorio();
    return usuario.idUsuario;
  }

  /// Carrega a lista de receitas próprias do usuário ativo.
  Future<void> carregarMinhasReceitas() async {
    carregando = true;
    erro = null;
    notifyListeners();

    try {
      final idAutor = await _obterIdAutorAtivo();
      receitas = await repositorio.listarReceitasProprias(idAutor);
    } catch (e) {
      erro = 'Não foi possível carregar as receitas: $e';
    } finally {
      carregando = false;
      notifyListeners();
    }
  }

  /// Carrega os detalhes completos da versão mais recente da receita.
  Future<void> carregarDetalhes(String idReceita) async {
    carregando = true;
    erro = null;
    notifyListeners();

    try {
      final idAutor = await _obterIdAutorAtivo();
      receitaSelecionada = await repositorio.obterReceitaPorId(
        idReceita: idReceita,
        idAutor: idAutor,
      );
      if (receitaSelecionada == null) {
        erro = 'Receita não encontrada.';
      }
    } catch (e) {
      erro = 'Erro ao carregar detalhes da receita: $e';
    } finally {
      carregando = false;
      notifyListeners();
    }
  }

  /// Abre o seletor da galeria para escolher uma imagem.
  Future<String?> escolherFotoGaleria() async {
    return await gerenciadorFotos.seletor.escolherFoto();
  }

  /// Salva uma receita nova ou uma nova versão caso esteja editando.
  Future<bool> salvarReceita(RascunhoReceita rascunho) async {
    final validacao = ValidadorReceita.validar(rascunho);
    if (!validacao.valido) {
      erro = validacao.erroTitulo ?? validacao.erroGeral ?? 'Verifique os campos obrigatórios.';
      notifyListeners();
      return false;
    }

    carregando = true;
    erro = null;
    notifyListeners();

    String? copiaRecenteRelativa;
    try {
      final idAutor = await _obterIdAutorAtivo();

      // Gerenciar foto
      String? caminhoFotoParaGravar;
      if (rascunho.removerFoto) {
        caminhoFotoParaGravar = null;
      } else if (rascunho.novaFotoCaminho != null) {
        copiaRecenteRelativa = await gerenciadorFotos.copiarParaApp(rascunho.novaFotoCaminho!);
        caminhoFotoParaGravar = copiaRecenteRelativa;
      } else {
        caminhoFotoParaGravar = rascunho.fotoAtual;
      }

      if (rascunho.idReceita == null) {
        // Criar nova receita
        await repositorio.criarReceitaPropria(
          idAutor: idAutor,
          rascunho: rascunho,
          caminhoFotoRelativo: caminhoFotoParaGravar,
        );
      } else {
        // Criar nova versão
        await repositorio.criarNovaVersao(
          idReceita: rascunho.idReceita!,
          idAutor: idAutor,
          rascunho: rascunho,
          caminhoFotoRelativo: caminhoFotoParaGravar,
        );
      }

      await carregarMinhasReceitas();
      return true;
    } catch (e) {
      if (copiaRecenteRelativa != null) {
        await gerenciadorFotos.limparCopiaRecente(copiaRecenteRelativa);
      }
      erro = 'Erro ao salvar a receita: $e';
      return false;
    } finally {
      carregando = false;
      notifyListeners();
    }
  }

  /// Exclui logicamente a receita após confirmação da tela.
  Future<bool> excluirReceita(String idReceita) async {
    carregando = true;
    erro = null;
    notifyListeners();

    try {
      final idAutor = await _obterIdAutorAtivo();
      final sucesso = await repositorio.excluirReceitaLogica(
        idReceita: idReceita,
        idAutor: idAutor,
      );
      if (sucesso) {
        await carregarMinhasReceitas();
      }
      return sucesso;
    } catch (e) {
      erro = 'Erro ao excluir a receita: $e';
      return false;
    } finally {
      carregando = false;
      notifyListeners();
    }
  }
}
