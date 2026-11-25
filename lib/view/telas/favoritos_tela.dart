import 'package:flutter/material.dart';
import '../../controller/controller_favoritos.dart';
import '../../controller/controller_preparo.dart';
import '../../controller/controller_receitas.dart';
import '../componentes/botoes.dart';
import '../componentes/cartao_receita.dart';
import '../componentes/esqueleto_carregamento.dart';
import '../componentes/estado_vazio.dart';
import '../theme/cores.dart';
import 'ficha_receita_tela.dart';

/// Aba Favoritos exibindo a lista de receitas marcadas com coração pelo usuário ativo.
class FavoritosTela extends StatefulWidget {
  final ControllerFavoritos? controller;
  final ControllerReceitas? controllerReceitas;
  final ControllerPreparo? controllerPreparo;

  const FavoritosTela({
    super.key,
    this.controller,
    this.controllerReceitas,
    this.controllerPreparo,
  });

  @override
  State<FavoritosTela> createState() => _FavoritosTelaState();
}

class _FavoritosTelaState extends State<FavoritosTela> {
  late final ControllerFavoritos _controller;
  late final ControllerReceitas _controllerReceitas;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ControllerFavoritos();
    _controllerReceitas = widget.controllerReceitas ?? ControllerReceitas();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.carregarFavoritos();
      }
    });
  }

  void _abrirFicha(String idReceita) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FichaReceitaTela(
          idReceita: idReceita,
          controller: _controllerReceitas,
          controllerPreparo: widget.controllerPreparo,
          controllerFavoritos: _controller,
        ),
      ),
    );
    _controller.carregarFavoritos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoritos'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            if (_controller.carregando && _controller.favoritos.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: EsqueletoCarregamento(quantidadeLinhas: 4),
              );
            }

            if (_controller.erro != null && _controller.favoritos.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: CoresApp.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _controller.erro!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: CoresApp.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      BotaoPrimario(
                        texto: 'Tentar novamente',
                        onPressed: _controller.carregarFavoritos,
                      ),
                    ],
                  ),
                ),
              );
            }

            if (_controller.favoritos.isEmpty) {
              return const EstadoVazio(
                icone: Icons.favorite_border,
                titulo: 'Nenhum favorito guardado',
                mensagem:
                    'Suas receitas marcadas com o coração aparecerão aqui para você encontrá-las rapidamente.',
              );
            }

            return RefreshIndicator(
              onRefresh: _controller.carregarFavoritos,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _controller.favoritos.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final rec = _controller.favoritos[index];
                  final rotuloCategoria = rec.origem == 'themealdb'
                      ? 'Fonte: TheMealDB • ${rec.categoria}'
                      : 'Versão ${rec.numeroVersao} • ${rec.categoria}';
                  return CartaoReceita(
                    titulo: rec.titulo,
                    categoria: rotuloCategoria,
                    foto: rec.foto,
                    ehFavorito: true,
                    onFavoritoTap: () => _controller.alternarFavorito(rec.idReceita),
                    onTap: () => _abrirFicha(rec.idReceita),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
