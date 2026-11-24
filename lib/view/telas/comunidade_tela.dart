import 'package:flutter/material.dart';
import '../componentes/estado_vazio.dart';

/// Aba Comunidade com estado vazio amigável.
class ComunidadeTela extends StatelessWidget {
  const ComunidadeTela({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comunidade'),
      ),
      body: const SafeArea(
        child: EstadoVazio(
          icone: Icons.public,
          titulo: 'Comunidade de Receitas',
          mensagem:
              'Em breve você poderá descobrir receitas publicadas por outros cozinheiros e compartilhar suas próprias criações culinárias.',
        ),
      ),
    );
  }
}
