import 'package:flutter/foundation.dart';
import '../model/repositorios/banco_dados.dart';
import '../model/repositorios/repositorio_receitas.dart';
import '../model/repositorios/repositorio_themealdb.dart';
import '../model/servicos/servico_traducao.dart';

/// Modos de busca suportados para exploração no TheMealDB.
enum ModoBuscaTheMealDb {
  nome,
  categoria,
  ingrediente,
}

/// Controller responsável pelo estado da tela de exploração do TheMealDB.
class ControllerExploracao extends ChangeNotifier {
  final RepositorioTheMealDb repositorioTheMealDb;
  final RepositorioReceitas repositorioReceitas;
  final BancoDados bancoDados;
  final ServicoTraducao servicoTraducao;

  ControllerExploracao({
    RepositorioTheMealDb? repositorioTheMealDb,
    RepositorioReceitas? repositorioReceitas,
    BancoDados? bancoDados,
    ServicoTraducao? servicoTraducao,
  })  : repositorioTheMealDb = repositorioTheMealDb ?? RepositorioTheMealDb(),
        repositorioReceitas = repositorioReceitas ?? RepositorioReceitas(),
        bancoDados = bancoDados ?? BancoDados.instancia,
        servicoTraducao = servicoTraducao ?? ServicoTraducao();

  ModoBuscaTheMealDb _modoBusca = ModoBuscaTheMealDb.nome;
  ModoBuscaTheMealDb get modoBusca => _modoBusca;

  String _termoBusca = '';
  String get termoBusca => _termoBusca;

  bool _carregando = false;
  bool get carregando => _carregando;

  String? _erro;
  String? get erro => _erro;

  List<ReceitaExternaResumo> _resultados = [];
  List<ReceitaExternaResumo> get resultados => List.unmodifiable(_resultados);

  List<String> _categorias = [];
  List<String> get categorias => List.unmodifiable(_categorias);

  bool _carregandoCategorias = false;
  bool get carregandoCategorias => _carregandoCategorias;

  String? _erroCategorias;
  String? get erroCategorias => _erroCategorias;

  List<ReceitaResumo> _receitasSalvas = [];
  List<ReceitaResumo> get receitasSalvas => List.unmodifiable(_receitasSalvas);

  bool _carregandoSalvas = false;
  bool get carregandoSalvas => _carregandoSalvas;

  String? _idUsuarioAtivo;
  int _sequenciaRequisicao = 0;

  Future<String> _obterIdUsuario() async {
    if (_idUsuarioAtivo != null) return _idUsuarioAtivo!;
    final usuario = await bancoDados.obterOuCriarUsuarioProvisorio();
    _idUsuarioAtivo = usuario.idUsuario;
    return _idUsuarioAtivo!;
  }

  /// Define o usuário ativo explicitamente (ex: em testes ou troca de conta).
  void definirUsuario(String idUsuario) {
    _idUsuarioAtivo = idUsuario;
  }

  /// Altera o modo de busca ativo.
  void alterarModo(ModoBuscaTheMealDb novoModo) {
    if (_modoBusca == novoModo) return;
    _modoBusca = novoModo;
    _erro = null;
    notifyListeners();
  }

  /// Inicializa categorias e receitas salvas do usuário.
  Future<void> inicializar() async {
    await Future.wait([
      carregarCategorias(),
      carregarReceitasSalvas(),
    ]);
  }

  /// Carrega a lista de categorias disponíveis no TheMealDB.
  Future<void> carregarCategorias() async {
    _carregandoCategorias = true;
    _erroCategorias = null;
    notifyListeners();

    try {
      _categorias = await repositorioTheMealDb.listarCategorias();
    } catch (e) {
      _erroCategorias = 'Não foi possível carregar as categorias.';
    } finally {
      _carregandoCategorias = false;
      notifyListeners();
    }
  }

  /// Carrega as receitas externas que o usuário já abriu ou favoritou no aparelho.
  Future<void> carregarReceitasSalvas() async {
    _carregandoSalvas = true;
    notifyListeners();

    try {
      final idUsuario = await _obterIdUsuario();
      _receitasSalvas = await repositorioReceitas.listarReceitasExternasSalvas(idUsuario);
    } catch (_) {
      // Falha silenciosa para não quebrar a tela se houver problema transitório
    } finally {
      _carregandoSalvas = false;
      notifyListeners();
    }
  }

  /// Executa busca na API TheMealDB de acordo com o modo ativo.
  /// Descarta respostas obsoletas se uma nova busca tiver sido disparada.
  Future<void> buscar(String termo) async {
    final termoLimpo = termo.trim();
    if (termoLimpo.isEmpty) {
      _erro = 'Informe um termo para pesquisar.';
      _resultados = [];
      notifyListeners();
      return;
    }

    _termoBusca = termoLimpo;
    final idRequisicao = ++_sequenciaRequisicao;

    _carregando = true;
    _erro = null;
    notifyListeners();

    try {
      final List<ReceitaExternaResumo> itens;
      switch (_modoBusca) {
        case ModoBuscaTheMealDb.nome:
          final termoEn = await servicoTraducao.termoBuscaParaIngles(termoLimpo);
          itens = await repositorioTheMealDb.buscarPorNome(termoEn);
          break;
        case ModoBuscaTheMealDb.categoria:
          final categoriaEn = servicoTraducao.categoriaParaIngles(termoLimpo);
          itens = await repositorioTheMealDb.buscarPorCategoria(categoriaEn);
          break;
        case ModoBuscaTheMealDb.ingrediente:
          final ingEn = await servicoTraducao.termoBuscaParaIngles(termoLimpo);
          itens = await repositorioTheMealDb.buscarPorIngrediente(ingEn);
          break;
      }

      // Traduz os títulos para Português
      final itensTraduzidos = await servicoTraducao.traduzirResultados(itens);

      // Se outra requisição foi iniciada enquanto esta aguardava, descarta esta resposta antiga
      if (idRequisicao != _sequenciaRequisicao) {
        return;
      }

      _resultados = itensTraduzidos;
      _erro = null;
    } catch (e) {
      if (idRequisicao != _sequenciaRequisicao) {
        return;
      }
      _erro = 'Não foi possível carregar as receitas da TheMealDB. Verifique sua conexão e tente novamente.';
      _resultados = [];
    } finally {
      if (idRequisicao == _sequenciaRequisicao) {
        _carregando = false;
        notifyListeners();
      }
    }
  }

  /// Abre a ficha completa de uma receita externa.
  /// Consulta na API online, traduz para Português/BR e salva cópia transacionalmente.
  /// Em caso de falha de conexão, recorre à cópia local salva se existente.
  Future<ReceitaCompleta?> abrirReceita(String idMeal) async {
    final idUsuario = await _obterIdUsuario();

    // 1. Tenta obter detalhes online e traduzir
    try {
      final ficha = await repositorioTheMealDb.obterDetalhesPorId(idMeal);
      if (ficha != null) {
        final fichaPt = await servicoTraducao.traduzirFichaParaPortugues(ficha);
        final completa = await repositorioReceitas.salvarCopiaExterna(
          idUsuario: idUsuario,
          ficha: fichaPt,
        );
        await carregarReceitasSalvas();
        return completa;
      }
    } catch (_) {
      // Falha de rede ou timeout: tenta fallback offline
    }

    // 2. Fallback offline: busca nos salvos locais do usuário
    final salvas = await repositorioReceitas.listarReceitasExternasSalvas(idUsuario);
    final salva = salvas.where((r) => r.idThemealdb == idMeal).firstOrNull;
    if (salva != null) {
      return await repositorioReceitas.obterReceitaPorId(
        idReceita: salva.idReceita,
        idUsuario: idUsuario,
      );
    }

    return null;
  }
}
