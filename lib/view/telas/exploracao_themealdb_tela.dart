import 'package:flutter/material.dart';
import '../../controller/controller_exploracao.dart';
import '../../controller/controller_favoritos.dart';
import '../../controller/controller_preparo.dart';
import '../../controller/controller_receitas.dart';
import '../componentes/botoes.dart';
import '../componentes/cartao_receita.dart';
import '../componentes/estado_vazio.dart';
import '../theme/cores.dart';
import 'ficha_receita_tela.dart';

/// Tela de exploração do catálogo TheMealDB com busca, filtros de categoria e receitas salvas.
class ExploracaoTheMealDbTela extends StatefulWidget {
  final ControllerExploracao? controller;
  final ControllerReceitas? controllerReceitas;
  final ControllerPreparo? controllerPreparo;
  final ControllerFavoritos? controllerFavoritos;

  const ExploracaoTheMealDbTela({
    super.key,
    this.controller,
    this.controllerReceitas,
    this.controllerPreparo,
    this.controllerFavoritos,
  });

  @override
  State<ExploracaoTheMealDbTela> createState() => _ExploracaoTheMealDbTelaState();
}

class _ExploracaoTheMealDbTelaState extends State<ExploracaoTheMealDbTela>
    with SingleTickerProviderStateMixin {
  late final ControllerExploracao _controller;
  late final ControllerReceitas _controllerReceitas;
  late final ControllerFavoritos _controllerFavoritos;
  late final TextEditingController _buscaTextController;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ControllerExploracao();
    _controllerReceitas = widget.controllerReceitas ?? ControllerReceitas();
    _controllerFavoritos = widget.controllerFavoritos ?? ControllerFavoritos();
    _buscaTextController = TextEditingController();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.inicializar();
        _controllerFavoritos.carregarFavoritos();
      }
    });
  }

  @override
  void dispose() {
    _buscaTextController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _executarBusca([String? termo]) {
    final query = termo ?? _buscaTextController.text;
    _controller.buscar(query);
  }

  Future<void> _abrirResultado(String idMeal) async {
    final completa = await _controller.abrirReceita(idMeal);
    if (!mounted) return;

    if (completa != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FichaReceitaTela(
            idReceita: completa.receita.idReceita,
            controller: _controllerReceitas,
            controllerPreparo: widget.controllerPreparo,
            controllerFavoritos: _controllerFavoritos,
          ),
        ),
      );
      _controller.carregarReceitasSalvas();
      _controllerFavoritos.carregarFavoritos();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível abrir os detalhes da receita. Verifique sua conexão.',
          ),
        ),
      );
    }
  }

  void _abrirFichaSalva(String idReceita) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FichaReceitaTela(
          idReceita: idReceita,
          controller: _controllerReceitas,
          controllerPreparo: widget.controllerPreparo,
          controllerFavoritos: _controllerFavoritos,
        ),
      ),
    );
    _controller.carregarReceitasSalvas();
    _controllerFavoritos.carregarFavoritos();
  }

  String _dicaModo() {
    switch (_controller.modoBusca) {
      case ModoBuscaTheMealDb.nome:
        return 'Buscar prato por nome (ex: frango, bolo)';
      case ModoBuscaTheMealDb.categoria:
        return 'Buscar por categoria (ex: Frutos do Mar, Sobremesa)';
      case ModoBuscaTheMealDb.ingrediente:
        return 'Buscar por ingrediente (ex: alho, frango, batata)';
    }
  }

  Widget _construirBarraBuscaEModos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Seletor de Modo
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Nome'),
              selected: _controller.modoBusca == ModoBuscaTheMealDb.nome,
              onSelected: (_) => _controller.alterarModo(ModoBuscaTheMealDb.nome),
            ),
            ChoiceChip(
              label: const Text('Categoria'),
              selected: _controller.modoBusca == ModoBuscaTheMealDb.categoria,
              onSelected: (_) => _controller.alterarModo(ModoBuscaTheMealDb.categoria),
            ),
            ChoiceChip(
              label: const Text('Ingrediente'),
              selected: _controller.modoBusca == ModoBuscaTheMealDb.ingrediente,
              onSelected: (_) => _controller.alterarModo(ModoBuscaTheMealDb.ingrediente),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Campo de Texto de Busca
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _buscaTextController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: _dicaModo(),
                  prefixIcon: const Icon(Icons.search, color: CoresApp.orange800),
                  suffixIcon: _buscaTextController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _buscaTextController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: CoresApp.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: CoresApp.line),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _executarBusca(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: CoresApp.orange800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                minimumSize: const Size(52, 52),
              ),
              icon: const Icon(Icons.search),
              tooltip: 'Pesquisar',
              onPressed: () => _executarBusca(),
            ),
          ],
        ),
        // Atalhos de categoria
        if (_controller.categorias.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _controller.categorias.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _controller.categorias[index];
                final catPt = _controller.servicoTraducao.categoriaParaPortugues(cat);
                return ActionChip(
                  label: Text(catPt),
                  onPressed: () {
                    _controller.alterarModo(ModoBuscaTheMealDb.categoria);
                    _buscaTextController.text = catPt;
                    _executarBusca(catPt);
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _construirResultadosBusca() {
    if (_controller.carregando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_controller.erro != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: CoresApp.error),
              const SizedBox(height: 12),
              Text(
                _controller.erro!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: CoresApp.ink, fontSize: 16),
              ),
              const SizedBox(height: 16),
              BotaoPrimario(
                texto: 'Tentar novamente',
                onPressed: () => _executarBusca(),
              ),
              const SizedBox(height: 12),
              BotaoSecundario(
                texto: 'Ver receitas salvas',
                onPressed: () => _tabController.animateTo(1),
              ),
            ],
          ),
        ),
      );
    }

    if (_controller.resultados.isEmpty && _controller.termoBusca.isNotEmpty) {
      return const EstadoVazio(
        icone: Icons.search_off_rounded,
        titulo: 'Nenhum resultado',
        mensagem: 'Não encontramos receitas para esse termo. Tente outro nome, ingrediente ou categoria.',
      );
    }

    if (_controller.resultados.isEmpty) {
      return const EstadoVazio(
        icone: Icons.travel_explore_rounded,
        titulo: 'Descubra receitas mundiais',
        mensagem: 'Digite um ingrediente, prato ou escolha uma categoria para buscar no catálogo TheMealDB.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _controller.resultados.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _controller.resultados[index];
        final ehFav = _controllerFavoritos.isFavoritoPorIdThemealdb(item.idMeal);
        return CartaoReceita(
          titulo: item.strMeal,
          categoria: 'TheMealDB',
          foto: item.strMealThumb,
          ehFavorito: ehFav,
          onFavoritoTap: () => _controllerFavoritos.alternarFavoritoTheMealDb(item.idMeal),
          onTap: () => _abrirResultado(item.idMeal),
        );
      },
    );
  }

  Widget _construirReceitasSalvas() {
    if (_controller.carregandoSalvas && _controller.receitasSalvas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.receitasSalvas.isEmpty) {
      return const EstadoVazio(
        icone: Icons.cloud_download_outlined,
        titulo: 'Nenhuma receita salva',
        mensagem:
            'As receitas que você abrir ou favoritar do TheMealDB ficarão salvas aqui para consulta mesmo sem conexão.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _controller.receitasSalvas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final rec = _controller.receitasSalvas[index];
        final ehFav = _controllerFavoritos.isFavorito(rec.idReceita);
        return CartaoReceita(
          titulo: rec.titulo,
          categoria: 'Fonte: TheMealDB • ${rec.categoria}',
          foto: rec.foto,
          ehFavorito: ehFav,
          onFavoritoTap: () => _controllerFavoritos.alternarFavorito(rec.idReceita),
          onTap: () => _abrirFichaSalva(rec.idReceita),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar TheMealDB'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: CoresApp.orange800,
          unselectedLabelColor: CoresApp.inkSoft,
          indicatorColor: CoresApp.orange800,
          tabs: const [
            Tab(text: 'Busca online', icon: Icon(Icons.search)),
            Tab(text: 'Receitas salvas', icon: Icon(Icons.bookmark_border)),
          ],
        ),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_controller, _controllerFavoritos]),
          builder: (context, _) {
            return TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Busca e Resultados
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      _construirBarraBuscaEModos(),
                      Expanded(child: _construirResultadosBusca()),
                    ],
                  ),
                ),
                // Tab 2: Receitas Salvas Offline
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: RefreshIndicator(
                    onRefresh: _controller.carregarReceitasSalvas,
                    child: _construirReceitasSalvas(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
