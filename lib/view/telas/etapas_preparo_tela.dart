import 'package:flutter/material.dart';
import '../../controller/controller_preparo.dart';
import '../componentes/botoes.dart';
import '../theme/cores.dart';
import 'conclusao_preparo_tela.dart';

/// Tela de etapas guiadas com uma instrução por vez, navegação e confirmação de conclusão.
class EtapasPreparoTela extends StatefulWidget {
  final ControllerPreparo controller;

  const EtapasPreparoTela({
    super.key,
    required this.controller,
  });

  @override
  State<EtapasPreparoTela> createState() => _EtapasPreparoTelaState();
}

class _EtapasPreparoTelaState extends State<EtapasPreparoTela> {
  void _confirmarConclusao() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Concluir preparo?'),
          content: const Text(
            'Tem certeza de que terminou todas as etapas desta receita? O preparo será registrado como concluído no seu histórico.',
            style: TextStyle(color: CoresApp.inkSoft, fontSize: 15),
          ),
          actions: [
            BotaoTerciario(
              texto: 'Cancelar',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            BotaoPrimario(
              texto: 'Concluir',
              onPressed: () async {
                Navigator.of(ctx).pop(); // Fecha diálogo
                final ok = await widget.controller.concluirPreparo();
                if (ok && mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => ConclusaoPreparoTela(
                        controller: widget.controller,
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final preparo = widget.controller.preparoAtual;
        if (preparo == null || preparo.etapas.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Modo de Preparo')),
            body: const Center(child: Text('Nenhuma etapa disponível.')),
          );
        }

        final totalEtapas = widget.controller.totalEtapas;
        final etapaAtual = widget.controller.etapaAtual;
        final etapaIndex = (etapaAtual - 1).clamp(0, totalEtapas - 1);
        final etapaObjeto = preparo.etapas[etapaIndex];
        final ehUltimaEtapa = etapaAtual == totalEtapas;

        return Scaffold(
          appBar: AppBar(
            title: Text(preparo.versao.titulo),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.checklist_rounded, size: 20),
                label: const Text('Checklist'),
                style: TextButton.styleFrom(foregroundColor: CoresApp.orange700),
                onPressed: () => Navigator.of(context).pop(), // Volta para o checklist
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Indicador de progresso e posição da etapa
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Etapa $etapaAtual de $totalEtapas',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: CoresApp.ink,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: CoresApp.orange100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${((etapaAtual / totalEtapas) * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: CoresApp.orange800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: etapaAtual / totalEtapas,
                      backgroundColor: CoresApp.line,
                      valueColor: const AlwaysStoppedAnimation<Color>(CoresApp.orange500),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Cartão com a instrução atual
                  Expanded(
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: CoresApp.line, width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: CoresApp.orange500,
                                child: Text(
                                  '$etapaAtual',
                                  style: const TextStyle(
                                    color: CoresApp.ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                etapaObjeto.instrucao,
                                style: const TextStyle(
                                  color: CoresApp.ink,
                                  fontSize: 18,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Ações de navegação (Anterior / Próxima ou Concluir)
                  Row(
                    children: [
                      if (etapaAtual > 1) ...[
                        Expanded(
                          child: BotaoSecundario(
                            texto: 'Anterior',
                            icone: const Icon(Icons.arrow_back_rounded, size: 20),
                            onPressed: () {
                              widget.controller.mudarEtapa(etapaAtual - 1);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ehUltimaEtapa
                            ? BotaoPrimario(
                                texto: 'Concluir preparo',
                                icone: const Icon(Icons.check_circle_outline_rounded, size: 20),
                                onPressed: _confirmarConclusao,
                              )
                            : BotaoPrimario(
                                texto: 'Próxima',
                                icone: const Icon(Icons.arrow_forward_rounded, size: 20),
                                onPressed: () {
                                  widget.controller.mudarEtapa(etapaAtual + 1);
                                },
                              ),
                      ),
                    ],
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
