import 'package:flutter/material.dart';
import '../componentes/botoes.dart';
import '../theme/cores.dart';

/// Tela exibida em caso de falha na inicialização do banco de dados, com opção de tentar novamente.
class TelaErroBanco extends StatelessWidget {
  final String mensagemErro;
  final VoidCallback onTentarNovamente;

  const TelaErroBanco({
    super.key,
    required this.mensagemErro,
    required this.onTentarNovamente,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: CoresApp.errorBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: CoresApp.error,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Falha ao carregar o banco de dados',
                  style: TextStyle(
                    color: CoresApp.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Não foi possível inicializar o armazenamento local.\nDetalhe: $mensagemErro',
                  style: const TextStyle(
                    color: CoresApp.inkSoft,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                BotaoPrimario(
                  texto: 'Tentar novamente',
                  onPressed: onTentarNovamente,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
