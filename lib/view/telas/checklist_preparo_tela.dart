import 'package:flutter/material.dart';
import '../../controller/controller_preparo.dart';
import '../componentes/botoes.dart';
import '../theme/cores.dart';
import 'etapas_preparo_tela.dart';

/// Tela de checklist de ingredientes de uma sessão de preparo (3 estados, contador e aviso).
class ChecklistPreparoTela extends StatefulWidget {
  final ControllerPreparo controller;

  const ChecklistPreparoTela({
    super.key,
    required this.controller,
  });

  @override
  State<ChecklistPreparoTela> createState() => _ChecklistPreparoTelaState();
}

class _ChecklistPreparoTelaState extends State<ChecklistPreparoTela> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final preparo = widget.controller.preparoAtual;
        if (preparo == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Checklist')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final totalItens = widget.controller.totalItens;
        final totalConferidos = widget.controller.totalConferidos;
        final temFaltantes = widget.controller.temFaltantes;
        final totalFalta = widget.controller.totalFalta;
        final totalTenho = widget.controller.totalTenho;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preparo.versao.titulo,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Text(
                  'Checklist de Ingredientes',
                  style: TextStyle(fontSize: 13, color: CoresApp.inkSoft),
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Faixa de resumo e contadores
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: CoresApp.orange50,
                  child: Row(
                    children: [
                      const Icon(Icons.checklist_rounded, color: CoresApp.orange700, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$totalConferidos de $totalItens conferidos',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: CoresApp.ink,
                              ),
                            ),
                            Text(
                              '$totalTenho tenho · $totalFalta falta',
                              style: const TextStyle(
                                fontSize: 13,
                                color: CoresApp.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Faixa de aviso caso haja faltantes (não bloqueante)
                if (temFaltantes)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CoresApp.yellow100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CoresApp.yellow400),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: CoresApp.orange800, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Atenção: você marcou $totalFalta ingrediente(s) como falta. Você pode continuar para as etapas, mas verifique se a ausência não prejudicará sua receita.',
                            style: const TextStyle(
                              color: CoresApp.ink,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Lista de ingredientes com 3 estados
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: preparo.conferencias.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = preparo.conferencias[index];
                      final estado = item.estado; // 'nao_conferido', 'tenho', 'falta'

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: estado == 'tenho'
                                ? CoresApp.success
                                : estado == 'falta'
                                    ? CoresApp.error
                                    : CoresApp.line,
                            width: estado == 'nao_conferido' ? 1 : 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.nomeIngrediente,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: CoresApp.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.medida,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: CoresApp.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Botões de marcação acessíveis com área de toque mínima de 48 dp
                              _BotaoEstadoConferencia(
                                label: 'Tenho',
                                icon: Icons.check,
                                corAtiva: CoresApp.success,
                                corFundoAtiva: CoresApp.successBg,
                                selecionado: estado == 'tenho',
                                onTap: () {
                                  final novo = estado == 'tenho' ? 'nao_conferido' : 'tenho';
                                  widget.controller.alterarConferencia(item.idItem, novo);
                                },
                              ),
                              const SizedBox(width: 6),
                              _BotaoEstadoConferencia(
                                label: 'Falta',
                                icon: Icons.close,
                                corAtiva: CoresApp.error,
                                corFundoAtiva: CoresApp.errorBg,
                                selecionado: estado == 'falta',
                                onTap: () {
                                  final novo = estado == 'falta' ? 'nao_conferido' : 'falta';
                                  widget.controller.alterarConferencia(item.idItem, novo);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Botão de avanço livre para as etapas
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: BotaoPrimario(
                      texto: 'Seguir para as etapas',
                      icone: const Icon(Icons.arrow_forward_rounded, size: 20),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EtapasPreparoTela(
                              controller: widget.controller,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BotaoEstadoConferencia extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color corAtiva;
  final Color corFundoAtiva;
  final bool selecionado;
  final VoidCallback onTap;

  const _BotaoEstadoConferencia({
    required this.label,
    required this.icon,
    required this.corAtiva,
    required this.corFundoAtiva,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selecionado ? corFundoAtiva : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selecionado ? corAtiva : CoresApp.line,
            width: selecionado ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selecionado ? corAtiva : CoresApp.disabled),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
                color: selecionado ? corAtiva : CoresApp.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
