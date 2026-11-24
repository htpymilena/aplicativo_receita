import 'package:flutter/material.dart';
import '../theme/cores.dart';

/// Tela inicial (Aba Início) com título e espaço reservado para busca e receitas.
class InicioTela extends StatelessWidget {
  const InicioTela({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CoresApp.orange50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: CoresApp.line, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'O que vamos cozinhar hoje?',
                      style: TextStyle(
                        color: CoresApp.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Explore suas receitas locais, busque por ingredientes que você tem na despensa e acompanhe seus preparos.',
                      style: TextStyle(
                        color: CoresApp.inkSoft,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Suas Receitas',
                style: TextStyle(
                  color: CoresApp.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                decoration: BoxDecoration(
                  color: CoresApp.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: CoresApp.line, width: 1),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 44,
                      color: CoresApp.orange700,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Nenhuma receita cadastrada ainda',
                      style: TextStyle(
                        color: CoresApp.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'O gerenciamento de receitas próprias será implementado na Etapa 2.',
                      style: TextStyle(
                        color: CoresApp.inkSoft,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
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
