import 'package:flutter/material.dart';
import '../../controller/controller_historico.dart';
import '../../controller/controller_preparo.dart';
import '../../controller/controller_receitas.dart';
import '../componentes/cartao_receita.dart';
import '../theme/cores.dart';
import 'checklist_preparo_tela.dart';
import 'detalhe_preparo_tela.dart';
import 'etapas_preparo_tela.dart';
import 'ficha_receita_tela.dart';
import 'formulario_receita_tela.dart';
import 'minhas_receitas_tela.dart';

/// Tela inicial (Aba Início) com faixas 'Continue de onde parou', 'Feitas recentemente' e 'Suas Receitas'.
class InicioTela extends StatefulWidget {
  final ControllerHistorico? controllerHistorico;
  final ControllerPreparo? controllerPreparo;
  final ControllerReceitas? controllerReceitas;

  const InicioTela({
    super.key,
    this.controllerHistorico,
    this.controllerPreparo,
    this.controllerReceitas,
  });

  @override
  State<InicioTela> createState() => _InicioTelaState();
}

class _InicioTelaState extends State<InicioTela> {
  late final ControllerHistorico _controllerHistorico;
  late final ControllerPreparo _controllerPreparo;
  late final ControllerReceitas _controllerReceitas;

  @override
  void initState() {
    super.initState();
    _controllerHistorico = widget.controllerHistorico ?? ControllerHistorico();
    _controllerPreparo = widget.controllerPreparo ?? ControllerPreparo();
    _controllerReceitas = widget.controllerReceitas ?? ControllerReceitas();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_controllerHistorico.emAndamento.isEmpty && _controllerHistorico.concluidos.isEmpty) {
          _controllerHistorico.carregarTudo();
        }
        _controllerReceitas.carregarMinhasReceitas();
      }
    });
  }

  void _retomarPreparo(String idPreparo, int ordemEtapaAtual) async {
    await _controllerPreparo.carregarPreparo(idPreparo);
    if (!mounted) return;

    if (ordemEtapaAtual > 1) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EtapasPreparoTela(controller: _controllerPreparo),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChecklistPreparoTela(controller: _controllerPreparo),
        ),
      );
    }
    _controllerHistorico.carregarTudo();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controllerHistorico, _controllerReceitas]),
      builder: (context, _) {
        final emAndamento = _controllerHistorico.emAndamento;
        final concluidos = _controllerHistorico.concluidos;
        final minhasReceitas = _controllerReceitas.receitas;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Início'),
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  _controllerHistorico.carregarTudo(),
                  _controllerReceitas.carregarMinhasReceitas(),
                ]);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Banner de boas-vindas
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: CoresApp.orange50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: CoresApp.line, width: 1),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'O que vamos cozinhar hoje?',
                            style: TextStyle(
                              color: CoresApp.ink,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Explore suas receitas locais, confira ingredientes na despensa e acompanhe seus preparos.',
                            style: TextStyle(
                              color: CoresApp.inkSoft,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Faixa 1: Continue de onde parou (preparos em andamento)
                    if (emAndamento.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Continue de onde parou',
                        style: TextStyle(
                          color: CoresApp.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: emAndamento.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final prep = emAndamento[index];
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: CoresApp.orange400, width: 1.5),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: const CircleAvatar(
                                backgroundColor: CoresApp.orange100,
                                child: Icon(Icons.timer_outlined, color: CoresApp.orange800),
                              ),
                              title: Text(
                                prep.tituloReceita,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: CoresApp.ink),
                              ),
                              subtitle: Text(
                                prep.totalEtapas > 0
                                    ? 'Etapa ${prep.ordemEtapaAtual} de ${prep.totalEtapas}'
                                    : 'Checklist de ingredientes',
                                style: const TextStyle(color: CoresApp.inkSoft, fontSize: 13),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: CoresApp.orange700),
                              onTap: () => _retomarPreparo(prep.idPreparo, prep.ordemEtapaAtual),
                            ),
                          );
                        },
                      ),
                    ],

                    // Faixa 2: Feitas recentemente (preparos concluídos)
                    if (concluidos.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Feitas recentemente',
                        style: TextStyle(
                          color: CoresApp.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: concluidos.take(3).length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final prep = concluidos[index];
                          final estrelas = prep.estrelas;
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: CoresApp.line),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              leading: const CircleAvatar(
                                backgroundColor: CoresApp.successBg,
                                child: Icon(Icons.check_circle_outline, color: CoresApp.success),
                              ),
                              title: Text(
                                prep.tituloReceita,
                                style: const TextStyle(fontWeight: FontWeight.w600, color: CoresApp.ink),
                              ),
                              subtitle: estrelas != null
                                  ? Row(
                                      children: [
                                        const Icon(Icons.star_rounded, color: CoresApp.star, size: 16),
                                        const SizedBox(width: 4),
                                        Text('$estrelas estrelas', style: const TextStyle(fontSize: 12, color: CoresApp.inkSoft)),
                                      ],
                                    )
                                  : const Text('Concluída', style: TextStyle(fontSize: 12, color: CoresApp.inkSoft)),
                              trailing: const Icon(Icons.chevron_right_rounded, color: CoresApp.inkSoft),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DetalhePreparoTela(
                                      idPreparo: prep.idPreparo,
                                      controller: _controllerHistorico,
                                    ),
                                  ),
                                );
                                _controllerHistorico.carregarTudo();
                              },
                            ),
                          );
                        },
                      ),
                    ],

                    // Faixa 3: Suas Receitas
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'Suas Receitas',
                          style: TextStyle(
                            color: CoresApp.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (minhasReceitas.isNotEmpty)
                          TextButton(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MinhasReceitasTela(controller: _controllerReceitas),
                                ),
                              );
                              _controllerReceitas.carregarMinhasReceitas();
                              _controllerHistorico.carregarTudo();
                            },
                            child: const Text(
                              'Ver todas',
                              style: TextStyle(
                                color: CoresApp.orange800,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (minhasReceitas.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        decoration: BoxDecoration(
                          color: CoresApp.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: CoresApp.line, width: 1),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.menu_book_outlined,
                              size: 40,
                              color: CoresApp.orange700,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Nenhuma receita cadastrada ainda',
                              style: TextStyle(
                                color: CoresApp.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'O gerenciamento de receitas próprias será implementado na Etapa 2.',
                              style: TextStyle(
                                color: CoresApp.inkSoft,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: CoresApp.orange500, width: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.add, color: CoresApp.orange700),
                                label: const Text(
                                  'Criar Primeira Receita',
                                  style: TextStyle(
                                    color: CoresApp.orange800,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                onPressed: () async {
                                  final criada = await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) => FormularioReceitaTela(controller: _controllerReceitas),
                                    ),
                                  );
                                  if (criada == true) {
                                    _controllerReceitas.carregarMinhasReceitas();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: minhasReceitas.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final rec = minhasReceitas[index];
                          return CartaoReceita(
                            titulo: rec.titulo,
                            categoria: rec.categoria,
                            foto: rec.fotoLocal,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => FichaReceitaTela(
                                    idReceita: rec.idReceita,
                                    controller: _controllerReceitas,
                                  ),
                                ),
                              );
                              _controllerReceitas.carregarMinhasReceitas();
                              _controllerHistorico.carregarTudo();
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
