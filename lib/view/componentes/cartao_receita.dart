import 'package:flutter/material.dart';
import '../theme/cores.dart';
import 'imagem_receita.dart';

/// Cartão de receita com raio de 20 dp, título, categoria e avaliação acessível.
class CartaoReceita extends StatelessWidget {
  final String titulo;
  final String categoria;
  final String? foto;
  final double? mediaEstrelas;
  final int? totalAvaliacoes;
  final VoidCallback? onTap;

  const CartaoReceita({
    super.key,
    required this.titulo,
    required this.categoria,
    this.foto,
    this.mediaEstrelas,
    this.totalAvaliacoes,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Foto da receita ou placeholder padronizado
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: ImagemReceita(
                    caminhoOuUrl: foto,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: CoresApp.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      categoria,
                      style: const TextStyle(
                        color: CoresApp.inkSoft,
                        fontSize: 14,
                      ),
                    ),
                    if (mediaEstrelas != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 16,
                            color: CoresApp.star,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            mediaEstrelas!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: CoresApp.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          if (totalAvaliacoes != null) ...[
                            Text(
                              ' ($totalAvaliacoes)',
                              style: const TextStyle(
                                color: CoresApp.inkSoft,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
