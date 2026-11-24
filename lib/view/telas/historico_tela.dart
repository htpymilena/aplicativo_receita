import 'package:flutter/material.dart';
import '../componentes/estado_vazio.dart';

/// Aba Histórico com estado vazio amigável.
class HistoricoTela extends StatelessWidget {
  const HistoricoTela({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
      ),
      body: const SafeArea(
        child: EstadoVazio(
          icone: Icons.history,
          titulo: 'Sem histórico de preparos',
          mensagem:
              'Quando você iniciar e concluir o preparo de um prato, o registro das conferências e avaliações ficará registrado aqui.',
        ),
      ),
    );
  }
}
