import 'package:flutter/material.dart';
import '../../controller/controller_historico.dart';
import '../componentes/selo_estado.dart';
import '../theme/cores.dart';

/// Tela de detalhe de um preparo histórico concluído, com dados da versão original e edição de nota.
class DetalhePreparoTela extends StatefulWidget {
  final String idPreparo;
  final ControllerHistorico controller;

  const DetalhePreparoTela({
    super.key,
    required this.idPreparo,
    required this.controller,
  });

  @override
  State<DetalhePreparoTela> createState() => _DetalhePreparoTelaState();
}

class _DetalhePreparoTelaState extends State<DetalhePreparoTela> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (widget.controller.detalhePreparo == null ||
            widget.controller.detalhePreparo!.preparo.idPreparo != widget.idPreparo) {
          widget.controller.carregarDetalhe(widget.idPreparo);
        }
      }
    });
  }

  void _abrirSeletorAvaliacao(int notaAtual) {
    int notaSelecionada = notaAtual > 0 ? notaAtual : 5;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Avaliação Pessoal'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Como ficou o seu prato? Esta avaliação é privada e fica salva apenas no seu aparelho.',
                    style: TextStyle(color: CoresApp.inkSoft, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starIndex = index + 1;
                      final ativa = starIndex <= notaSelecionada;
                      return IconButton(
                        iconSize: 32,
                        padding: const EdgeInsets.all(2),
                        icon: Icon(
                          ativa ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: ativa ? CoresApp.star : CoresApp.disabled,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            notaSelecionada = starIndex;
                          });
                        },
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CoresApp.orange500,
                    foregroundColor: CoresApp.ink,
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await widget.controller.atualizarAvaliacao(widget.idPreparo, notaSelecionada);
                    setState(() {});
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (widget.controller.carregando && widget.controller.detalhePreparo == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalhes do Preparo')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final detalhe = widget.controller.detalhePreparo;
        if (detalhe == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalhes do Preparo')),
            body: Center(
              child: Text(
                widget.controller.erro ?? 'Preparo não encontrado.',
                style: const TextStyle(color: CoresApp.error),
              ),
            ),
          );
        }

        final receitaExcluida = detalhe.receita.excluidaEm != null;
        final estrelas = detalhe.avaliacao?.estrelas;

        return Scaffold(
          appBar: AppBar(
            title: Text(detalhe.versao.titulo),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabeçalho com título, selos e status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detalhe.versao.titulo,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: CoresApp.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  label: Text('Versão ${detalhe.versao.numeroVersao}'),
                                  backgroundColor: CoresApp.orange100,
                                  labelStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: CoresApp.orange800,
                                  ),
                                ),
                                if (receitaExcluida)
                                  const Chip(
                                    label: Text('Receita indisponível'),
                                    backgroundColor: CoresApp.disabledBg,
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: CoresApp.inkSoft,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Cartão de Avaliação Pessoal
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: CoresApp.line),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Sua Avaliação',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: CoresApp.ink,
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.edit, size: 16),
                                label: Text(estrelas != null ? 'Alterar' : 'Avaliar'),
                                style: TextButton.styleFrom(foregroundColor: CoresApp.orange700),
                                onPressed: () => _abrirSeletorAvaliacao(estrelas ?? 0),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (estrelas != null) ...[
                            Row(
                              children: [
                                Row(
                                  children: List.generate(5, (i) {
                                    return Icon(
                                      i < estrelas ? Icons.star_rounded : Icons.star_outline_rounded,
                                      color: i < estrelas ? CoresApp.star : CoresApp.disabled,
                                      size: 24,
                                    );
                                  }),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$estrelas de 5 estrelas',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: CoresApp.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            const Text(
                              'Nenhuma nota registrada para este preparo.',
                              style: TextStyle(color: CoresApp.inkSoft, fontSize: 14),
                            ),
                          ],
                          const SizedBox(height: 8),
                          const SeloEstado(tipo: TipoSelo.privada),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Ingredientes da versão original preparada
                  const Text(
                    'Ingredientes Utilizados',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: CoresApp.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: CoresApp.line),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: detalhe.conferencias.map((conf) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Icon(
                                  conf.estado == 'tenho'
                                      ? Icons.check_circle_outline
                                      : conf.estado == 'falta'
                                          ? Icons.highlight_off
                                          : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: conf.estado == 'tenho'
                                      ? CoresApp.success
                                      : conf.estado == 'falta'
                                          ? CoresApp.error
                                          : CoresApp.disabled,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    conf.nomeIngrediente,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: CoresApp.ink,
                                    ),
                                  ),
                                ),
                                Text(
                                  conf.medida,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: CoresApp.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Etapas da versão original preparada
                  const Text(
                    'Modo de Preparo Realizado',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: CoresApp.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: CoresApp.line),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: detalhe.etapas.map((etapa) {
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
