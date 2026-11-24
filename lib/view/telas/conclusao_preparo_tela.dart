import 'package:flutter/material.dart';
import '../../controller/controller_preparo.dart';
import '../componentes/botoes.dart';
import '../componentes/selo_estado.dart';
import '../theme/cores.dart';

/// Tela de conclusão do preparo com avaliação opcional de 1 a 5 estrelas (sempre privada).
class ConclusaoPreparoTela extends StatefulWidget {
  final ControllerPreparo controller;

  const ConclusaoPreparoTela({
    super.key,
    required this.controller,
  });

  @override
  State<ConclusaoPreparoTela> createState() => _ConclusaoPreparoTelaState();
}

class _ConclusaoPreparoTelaState extends State<ConclusaoPreparoTela> {
  int _estrelasSelecionadas = 0;
  bool _salvando = false;

  void _finalizar() {
    // Retorna para a tela raiz do aplicativo
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _salvarNota() async {
    if (_estrelasSelecionadas == 0) return;
    setState(() => _salvando = true);
    await widget.controller.salvarAvaliacao(_estrelasSelecionadas);
    if (mounted) {
      _finalizar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final preparo = widget.controller.preparoAtual;
    final tituloReceita = preparo?.versao.titulo ?? 'Receita';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _finalizar();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Preparo Concluído'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: CoresApp.successBg,
                  child: Icon(Icons.check_circle_rounded, color: CoresApp.success, size: 52),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Parabéns!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: CoresApp.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Você concluiu o preparo de "$tituloReceita".',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: CoresApp.inkSoft,
                  ),
                ),
                const SizedBox(height: 24),

                // Seção de avaliação
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: CoresApp.line, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      children: [
                        const Text(
                          'Como ficou o seu prato?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: CoresApp.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            final estrelaIndex = index + 1;
                            final ativa = estrelaIndex <= _estrelasSelecionadas;
                            return IconButton(
                              iconSize: 36,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                              icon: Icon(
                                ativa ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: ativa ? CoresApp.star : CoresApp.disabled,
                              ),
                              onPressed: () {
                                setState(() {
                                  _estrelasSelecionadas = estrelaIndex;
                                });
                              },
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        const SeloEstado(
                          tipo: TipoSelo.privada,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Ações
                if (_estrelasSelecionadas > 0) ...[
                  SizedBox(
                    width: double.infinity,
                    child: BotaoPrimario(
                      texto: 'Salvar avaliação',
                      icone: _salvando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: CoresApp.ink),
                            )
                          : const Icon(Icons.check_rounded, size: 20),
                      onPressed: _salvando ? null : _salvarNota,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: BotaoTerciario(
                    texto: _estrelasSelecionadas > 0 ? 'Concluir sem salvar nota' : 'Pular avaliação',
                    onPressed: _finalizar,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
