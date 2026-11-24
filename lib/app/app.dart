import 'package:flutter/material.dart';
import '../view/theme/tema.dart';
import '../view/telas/navegacao_principal.dart';

/// Aplicação principal configurada com o tema do guia de design e navegação base.
class AppReceitas extends StatelessWidget {
  final Widget? telaInicial;

  const AppReceitas({
    super.key,
    this.telaInicial,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Receitas',
      debugShowCheckedModeBanner: false,
      theme: TemaApp.tema,
      home: telaInicial ?? const NavegacaoPrincipal(),
    );
  }
}
