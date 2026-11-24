import 'package:flutter/material.dart';
import '../theme/cores.dart';

/// Esqueleto de carregamento com caixas reservadas para evitar tela branca.
class EsqueletoCarregamento extends StatelessWidget {
  final int quantidadeLinhas;

  const EsqueletoCarregamento({
    super.key,
    this.quantidadeLinhas = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carregando conteúdo...',
      child: Column(
        children: List.generate(quantidadeLinhas, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CoresApp.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CoresApp.line, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: CoresApp.orange50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(
                          color: CoresApp.orange50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 120,
                        height: 14,
                        decoration: BoxDecoration(
                          color: CoresApp.disabledBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
