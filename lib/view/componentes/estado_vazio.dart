import 'package:flutter/material.dart';
import '../theme/cores.dart';

/// Componente de estado vazio com ilustração vetorial local e frase amigável.
class EstadoVazio extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String mensagem;
  final Widget? acao;

  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.mensagem,
    this.acao,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: CoresApp.orange50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icone,
                size: 48,
                color: CoresApp.orange700,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              titulo,
              style: const TextStyle(
                color: CoresApp.ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              mensagem,
              style: const TextStyle(
                color: CoresApp.inkSoft,
                fontSize: 15,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (acao != null) ...[
              const SizedBox(height: 24),
              acao!,
            ],
          ],
        ),
      ),
    );
  }
}
