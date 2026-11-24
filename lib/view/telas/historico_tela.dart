import 'package:flutter/material.dart';
import '../../controller/controller_historico.dart';
import '../componentes/estado_vazio.dart';
import '../theme/cores.dart';
import 'detalhe_preparo_tela.dart';

/// Aba Histórico listando preparos concluídos em ordem decrescente, com estado vazio e selo 'Receita indisponível'.
class HistoricoTela extends StatefulWidget {
  final ControllerHistorico? controller;

  const HistoricoTela({
    super.key,
    this.controller,
  });

  @override
  State<HistoricoTela> createState() => _HistoricoTelaState();
}

class _HistoricoTelaState extends State<HistoricoTela> {
  late final ControllerHistorico _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ControllerHistorico();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.concluidos.isEmpty) {
        _controller.carregarTudo();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final concluidos = _controller.concluidos;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Histórico'),
          ),
          body: SafeArea(
            child: _controller.carregando && concluidos.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : concluidos.isEmpty
                    ? const EstadoVazio(
                        icone: Icons.history,
                        titulo: 'Sem histórico de preparos',
                        mensagem:
                            'Quando você iniciar e concluir o preparo de um prato, o registro das conferências e avaliações ficará registrado aqui.',
                      )
                    : RefreshIndicator(
                        onRefresh: _controller.carregarTudo,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: concluidos.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final prep = concluidos[index];
                            final estrelas = prep.estrelas;
                            final concluidoEm = prep.concluidoEm;
                            final dataFormatada = concluidoEm != null
                                ? '${concluidoEm.day.toString().padLeft(2, '0')}/${concluidoEm.month.toString().padLeft(2, '0')}/${concluidoEm.year}'
                                : '';

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: CoresApp.line),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => DetalhePreparoTela(
                                        idPreparo: prep.idPreparo,
                                        controller: _controller,
                                      ),
                                    ),
                                  );
                                  _controller.carregarTudo();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              prep.tituloReceita,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: CoresApp.ink,
                                              ),
                                            ),
                                          ),
                                          if (prep.receitaExcluida)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: CoresApp.disabledBg,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'Receita indisponível',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: CoresApp.inkSoft,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Concluído em $dataFormatada',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: CoresApp.inkSoft,
                                            ),
                                          ),
                                          if (estrelas != null)
                                            Row(
                                              children: [
                                                const Icon(Icons.star_rounded, color: CoresApp.star, size: 18),
                                                const SizedBox(width: 2),
                                                Text(
                                                  '$estrelas',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: CoresApp.ink,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        );
      },
    );
  }
}
