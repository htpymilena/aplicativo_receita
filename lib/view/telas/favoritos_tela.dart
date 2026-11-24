import 'package:flutter/material.dart';
import '../componentes/estado_vazio.dart';

/// Aba Favoritos com estado vazio amigável.
class FavoritosTela extends StatelessWidget {
  const FavoritosTela({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoritos'),
      ),
      body: const SafeArea(
        child: EstadoVazio(
          icone: Icons.favorite_border,
          titulo: 'Nenhum favorito guardado',
          mensagem:
              'Suas receitas marcadas com o coração aparecerão aqui para você encontrá-las rapidamente.',
        ),
      ),
    );
  }
}
