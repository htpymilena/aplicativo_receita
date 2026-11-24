import 'package:flutter/material.dart';
import '../../controller/controller_receitas.dart';
import '../theme/cores.dart';
import 'minhas_receitas_tela.dart';

/// Aba Perfil com acesso direto a "Minhas receitas".
class PerfilTela extends StatelessWidget {
  final ControllerReceitas? controller;

  const PerfilTela({
    super.key,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
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
                  color: CoresApp.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: CoresApp.line, width: 1),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: CoresApp.orange100,
                      child: Icon(
                        Icons.person,
                        size: 36,
                        color: CoresApp.orange700,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cozinheiro Local',
                            style: TextStyle(
                              color: CoresApp.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Identidade provisória no aparelho',
                            style: TextStyle(
                              color: CoresApp.inkSoft,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: CoresApp.orange50,
                    child: Icon(Icons.restaurant_menu, color: CoresApp.orange700),
                  ),
                  title: const Text(
                    'Minhas receitas',
                    style: TextStyle(
                      color: CoresApp.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: const Text(
                    'Criar, consultar e gerenciar suas receitas autorais',
                    style: TextStyle(
                      color: CoresApp.inkSoft,
                      fontSize: 14,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: CoresApp.orange700),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MinhasReceitasTela(controller: controller),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
