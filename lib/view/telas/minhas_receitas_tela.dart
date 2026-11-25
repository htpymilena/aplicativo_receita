import 'package:flutter/material.dart';
import '../../controller/controller_favoritos.dart';
import '../../controller/controller_receitas.dart';
import '../componentes/botoes.dart';
import '../componentes/cartao_receita.dart';
import '../componentes/esqueleto_carregamento.dart';
import '../componentes/estado_vazio.dart';
import 'ficha_receita_tela.dart';
import 'formulario_receita_tela.dart';

class MinhasReceitasTela extends StatefulWidget {
  final ControllerReceitas? controller;
  final ControllerFavoritos? controllerFavoritos;

  const MinhasReceitasTela({
    super.key,
    this.controller,
    this.controllerFavoritos,
  });

  @override
  State<MinhasReceitasTela> createState() => _MinhasReceitasTelaState();
}

class _MinhasReceitasTelaState extends State<MinhasReceitasTela> {
  late ControllerReceitas _controller;
  late ControllerFavoritos _controllerFavoritos;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ControllerReceitas();
    _controllerFavoritos = widget.controllerFavoritos ?? ControllerFavoritos();
    _controller.carregarMinhasReceitas();
    _controllerFavoritos.carregarFavoritos();
  }

  void _abrirFormularioNovaReceita() async {
    final criada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormularioReceitaTela(controller: _controller),
      ),
    );
    if (criada == true) {
      _controller.carregarMinhasReceitas();
      _controllerFavoritos.carregarFavoritos();
    }
  }

  void _abrirFichaReceita(String idReceita) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FichaReceitaTela(
          idReceita: idReceita,
          controller: _controller,
          controllerFavoritos: _controllerFavoritos,
        ),
      ),
    );
    _controller.carregarMinhasReceitas();
    _controllerFavoritos.carregarFavoritos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Receitas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nova receita',
            onPressed: _abrirFormularioNovaReceita,
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_controller, _controllerFavoritos]),
          builder: (context, _) {
            if (_controller.carregando && _controller.receitas.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: EsqueletoCarregamento(quantidadeLinhas: 4),
              );
            }

            if (_controller.receitas.isEmpty) {
              return EstadoVazio(
                icone: Icons.menu_book,
                titulo: 'Nenhuma receita ainda',
                mensagem:
                    'Crie sua primeira receita autoral para começar o seu livro de culinária offline.',
                acao: BotaoPrimario(
                  texto: 'Nova receita',
                  onPressed: _abrirFormularioNovaReceita,
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  _controller.carregarMinhasReceitas(),
                  _controllerFavoritos.carregarFavoritos(),
                ]);
              },
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _controller.receitas.length,
                itemBuilder: (context, index) {
                  final receita = _controller.receitas[index];
                  return CartaoReceita(
                    titulo: receita.titulo,
                    categoria: 'Versão ${receita.numeroVersao} • ${receita.categoria}',
                    foto: receita.fotoLocal,
                    ehFavorito: _controllerFavoritos.isFavorito(receita.idReceita),
                    onFavoritoTap: () => _controllerFavoritos.alternarFavorito(receita.idReceita),
                    onTap: () => _abrirFichaReceita(receita.idReceita),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormularioNovaReceita,
        icon: const Icon(Icons.add),
        label: const Text('Nova receita'),
      ),
    );
  }
}
