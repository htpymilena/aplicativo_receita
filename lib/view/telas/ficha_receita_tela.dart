import 'package:flutter/material.dart';
import '../../controller/controller_receitas.dart';
import '../componentes/botoes.dart';
import '../componentes/imagem_receita.dart';
import '../componentes/selo_estado.dart';
import '../theme/cores.dart';
import 'formulario_receita_tela.dart';

class FichaReceitaTela extends StatefulWidget {
  final String idReceita;
  final ControllerReceitas controller;

  const FichaReceitaTela({
    super.key,
    required this.idReceita,
    required this.controller,
  });

  @override
  State<FichaReceitaTela> createState() => _FichaReceitaTelaState();
}

class _FichaReceitaTelaState extends State<FichaReceitaTela> {
  String? _caminhoFotoResolvido;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (widget.controller.receitaSelecionada == null ||
        widget.controller.receitaSelecionada!.receita.idReceita != widget.idReceita) {
      await widget.controller.carregarDetalhes(widget.idReceita);
    }
    final detalhes = widget.controller.receitaSelecionada;
    if (detalhes?.versao.fotoLocal != null) {
      final path = await widget.controller.gerenciadorFotos.resolverCaminhoCompleto(
        detalhes!.versao.fotoLocal,
      );
      if (mounted) {
        setState(() {
          _caminhoFotoResolvido = path;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _caminhoFotoResolvido = null;
        });
      }
    }
  }

  void _abrirEdicao() async {
    final detalhes = widget.controller.receitaSelecionada;
    if (detalhes == null) return;

    final atualizou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormularioReceitaTela(
          controller: widget.controller,
          receitaParaEditar: detalhes,
        ),
      ),
    );

    if (atualizou == true) {
      await widget.controller.carregarDetalhes(widget.idReceita);
      _carregar();
    }
  }

  void _confirmarExclusao() {
    final detalhes = widget.controller.receitaSelecionada;
    if (detalhes == null) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Excluir receita?'),
          content: Text(
            'Tem certeza de que deseja excluir "${detalhes.versao.titulo}"? A receita será removida das suas listas, mas o histórico de preparos anteriores será preservado.',
            style: const TextStyle(color: CoresApp.inkSoft, fontSize: 15),
          ),
          actions: [
            BotaoTerciario(
              texto: 'Cancelar',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final sucesso = await widget.controller.excluirReceita(widget.idReceita);
                if (sucesso && mounted) {
                  Navigator.of(context).pop(); // Retorna para Minhas receitas
                }
              },
              child: const Text(
                'Excluir',
                style: TextStyle(
                  color: CoresApp.error,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _construirFotoOuPlaceholder() {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ImagemReceita(
          caminhoOuUrl: _caminhoFotoResolvido,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final detalhes = widget.controller.receitaSelecionada;

        if (widget.controller.carregando && detalhes == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (detalhes == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Receita')),
            body: Center(
              child: Text(widget.controller.erro ?? 'Receita não encontrada'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(detalhes.versao.titulo),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar receita',
                onPressed: _abrirEdicao,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: CoresApp.error),
                tooltip: 'Excluir receita',
                onPressed: _confirmarExclusao,
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _construirFotoOuPlaceholder(),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const SeloEstado(
                        tipo: TipoSelo.privada,
                        textoCustomizado: 'Privada',
                      ),
                      const SeloEstado(
                        tipo: TipoSelo.tenho,
                        textoCustomizado: 'Salvo no aparelho',
                      ),
                      if (detalhes.versao.categoria.isNotEmpty &&
                          detalhes.versao.categoria != 'Sem categoria')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: CoresApp.orange100,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            detalhes.versao.categoria,
                            style: const TextStyle(
                              color: CoresApp.orange800,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: CoresApp.orange50,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Versão ${detalhes.versao.numeroVersao}',
                          style: const TextStyle(
                            color: CoresApp.orange800,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    detalhes.versao.titulo,
                    style: const TextStyle(
                      color: CoresApp.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Ingredientes',
                    style: TextStyle(
                      color: CoresApp.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: detalhes.itens.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.circle, size: 8, color: CoresApp.orange700),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.nomeIngrediente,
                                    style: const TextStyle(
                                      color: CoresApp.ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  item.medida,
                                  style: const TextStyle(
                                    color: CoresApp.inkSoft,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Modo de Preparo',
                    style: TextStyle(
                      color: CoresApp.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: detalhes.etapas.map((etapa) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: CoresApp.orange100,
                                  child: Text(
                                    '${etapa.ordem}',
                                    style: const TextStyle(
                                      color: CoresApp.orange800,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    etapa.instrucao,
                                    style: const TextStyle(
                                      color: CoresApp.ink,
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  BotaoSecundario(
                    texto: 'Editar receita',
                    icone: const Icon(Icons.edit, size: 20),
                    onPressed: _abrirEdicao,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
